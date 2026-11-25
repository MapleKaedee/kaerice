use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use serde::Serialize;
use serde_json::Value;
use tokio::sync::{Mutex, watch};
use tokio::time;
use zbus::message::Type::Signal;
use zbus::proxy::MethodFlags;
use zbus::{Connection, MatchRule, ObjectPath, OwnedObjectPath, OwnedVariant, Proxy, Variant};

use crate::follow::{call, code, follow};
use crate::server::{Answer, Topics, publish};

const NAME: &str = "net.connman.iwd";
const DEVICE: &str = "net.connman.iwd.Device";
const STATION: &str = "net.connman.iwd.Station";
const NETWORK: &str = "net.connman.iwd.Network";
const AGENTS: &str = "net.connman.iwd.AgentManager";
const OBJECTS: &str = "org.freedesktop.DBus.ObjectManager";
const PROPERTIES: &str = "org.freedesktop.DBus.Properties";
/// The path of our own agent.
const AGENT: &str = "/net/kaerice/agent";

type Interfaces = HashMap<String, HashMap<String, OwnedVariant>>;
type Objects = HashMap<OwnedObjectPath, Interfaces>;

#[derive(Debug, Default, PartialEq, Serialize)]
pub struct State {
    device: Option<String>,
    powered: bool,
    scanning: bool,
    /// Strongest first.
    networks: Vec<Network>,
}

#[derive(Debug, PartialEq, Serialize)]
struct Network {
    path: String,
    name: String,
    #[serde(rename = "type")]
    kind: String,
    known: bool,
    connected: bool,
    dbm: i16,
}

/// `ordered`: the answer of GetOrderedNetworks, in 1/100 dBm.
fn state(objects: &Objects, ordered: &[(OwnedObjectPath, i16)]) -> State {
    let Some((_, here)) = device(objects) else {
        return State::default();
    };
    let networks = ordered.iter().filter_map(|(path, level)| {
        let network = objects.get(path)?.get(NETWORK)?;
        Some(Network {
            path: path.to_string(),
            name: text(network, "Name")?,
            kind: text(network, "Type")?,
            known: network.contains_key("KnownNetwork"),
            connected: flag(network, "Connected"),
            dbm: level / 100,
        })
    });
    State {
        device: text(&here[DEVICE], "Name"),
        powered: flag(&here[DEVICE], "Powered"),
        scanning: here.get(STATION).is_some_and(|s| flag(s, "Scanning")),
        networks: networks.collect(),
    }
}

/// The first one by path: the map has no order of its own.
fn device(objects: &Objects) -> Option<(&OwnedObjectPath, &Interfaces)> {
    objects
        .iter()
        .filter(|(_, interfaces)| interfaces.contains_key(DEVICE))
        .min_by_key(|(path, _)| path.as_str())
}

fn text(properties: &HashMap<String, OwnedVariant>, name: &str) -> Option<String> {
    let text: &str = properties.get(name)?.downcast_ref().ok()?;
    Some(text.to_owned())
}

fn flag(properties: &HashMap<String, OwnedVariant>, name: &str) -> bool {
    properties
        .get(name)
        .is_some_and(|v| v.downcast_ref().unwrap_or(false))
}

/// Keeps the "wifi" topic up to date. Ends only when the bus connection is lost.
pub async fn watch(
    conn: &Connection,
    tx: &watch::Sender<Topics>,
    timeout: Duration,
) -> zbus::Result<()> {
    let signals = |interface| {
        MatchRule::builder()
            .msg_type(Signal)
            .sender(NAME)
            .interface(interface)
            .build()
    };
    let rules = vec![signals(PROPERTIES)?, signals(OBJECTS)?];
    follow(
        conn,
        NAME,
        rules,
        timeout,
        || read(conn),
        |state| publish(tx, "wifi", &state.unwrap_or_default()),
    )
    .await
}

async fn read(conn: &Connection) -> zbus::Result<State> {
    let objects = objects(conn).await?;
    let ordered = match device(&objects) {
        Some((path, here)) if here.contains_key(STATION) => {
            call(conn, NAME, path, STATION, "GetOrderedNetworks", &()).await?
        }
        _ => Vec::new(),
    };
    Ok(state(&objects, &ordered))
}

async fn objects(conn: &Connection) -> zbus::Result<Objects> {
    call(conn, NAME, "/", OBJECTS, "GetManagedObjects", &()).await
}

/// The "wifi.*" calls.
#[derive(Clone)]
pub struct Wifi {
    conn: Connection,
    timeout: Duration,
    connecting: Arc<Mutex<()>>,
}

impl Wifi {
    pub fn new(conn: Connection, timeout: Duration) -> Wifi {
        Wifi {
            conn,
            timeout,
            connecting: Arc::default(),
        }
    }

    /// `what`: the part of the name after "wifi."
    pub async fn call(&self, what: &str, args: &Value) -> Answer {
        match what {
            "scan" => self.limit(self.station("Scan")).await,
            "disconnect" => self.limit(self.station("Disconnect")).await,
            "power" => {
                let on = args["on"].as_bool().ok_or("InvalidArgs")?;
                self.limit(self.power(on)).await
            }
            "connect" => {
                let path = args["path"].as_str().unwrap_or_default();
                let network = OwnedObjectPath::try_from(path).map_err(|_| "InvalidArgs")?;
                match args["passphrase"].as_str() {
                    None | Some("") => self.limit(self.connect(&network)).await,
                    Some(passphrase) => self.join(network, passphrase.to_owned()).await,
                }
            }
            _ => Err("UnknownCall".into()),
        }
    }

    async fn limit(&self, work: impl Future<Output = Answer>) -> Answer {
        time::timeout(self.timeout, work)
            .await
            .unwrap_or_else(|_| Err("Timeout".into()))
    }

    async fn device(&self) -> Result<OwnedObjectPath, String> {
        let objects = objects(&self.conn).await.map_err(code)?;
        let (path, _) = device(&objects).ok_or("Unavailable")?;
        Ok(path.clone())
    }

    async fn station(&self, method: &str) -> Answer {
        let path = self.device().await?;
        call(&self.conn, NAME, &path, STATION, method, &())
            .await
            .map_err(code)
    }

    async fn power(&self, on: bool) -> Answer {
        let path = self.device().await?;
        let body = (DEVICE, "Powered", Variant::from(on));
        call(&self.conn, NAME, &path, PROPERTIES, "Set", &body)
            .await
            .map_err(code)
    }

    async fn connect(&self, network: &str) -> Answer {
        call(&self.conn, NAME, network, NETWORK, "Connect", &())
            .await
            .map_err(code)
    }

    /// Connects with an agent that lives as long as this takes.
    async fn join(&self, network: OwnedObjectPath, passphrase: String) -> Answer {
        let _one = self.connecting.try_lock().map_err(|_| "Busy")?;
        let server = self.conn.object_server();
        let agent = Agent {
            network: network.clone(),
            passphrase,
        };
        server.at(AGENT, agent).await.map_err(code)?;
        let answer = self
            .limit(async {
                self.agents("RegisterAgent", MethodFlags::NO_AUTO_START)
                    .await
                    .map_err(code)?;
                self.connect(&network).await
            })
            .await;
        let _ = server.remove::<Agent, _>(AGENT).await;
        // without waiting: an iwd that hangs does not answer this either
        let flags = MethodFlags::NO_AUTO_START | MethodFlags::NO_REPLY_EXPECTED;
        let _ = self.agents("UnregisterAgent", flags).await;
        answer
    }

    async fn agents(&self, method: &str, flags: MethodFlags) -> zbus::Result<()> {
        let agent = ObjectPath::from_static_str(AGENT)?;
        Proxy::new(&self.conn, NAME, "/net/connman/iwd", AGENTS)
            .await?
            .call_with_flags::<_, _, ()>(method, flags, &agent)
            .await?;
        Ok(())
    }
}

/// Answers iwd's question for the password. Its other calls (Release, Cancel) want no answer.
struct Agent {
    network: OwnedObjectPath,
    passphrase: String,
}

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "net.connman.iwd.Agent.Error")]
enum AgentError {
    Canceled,
}

#[zbus::interface(name = "net.connman.iwd.Agent")]
impl Agent {
    fn request_passphrase(&self, network: OwnedObjectPath) -> Result<String, AgentError> {
        if network != self.network {
            return Err(AgentError::Canceled);
        }
        Ok(self.passphrase.clone())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const STATION_PATH: &str = "/net/connman/iwd/0/3";
    const HOME: &str = "/net/connman/iwd/0/3/home_psk";
    const CAFE: &str = "/net/connman/iwd/0/3/cafe_open";

    fn path(text: &str) -> OwnedObjectPath {
        text.try_into().unwrap()
    }

    fn props(list: &[(&str, Variant<'_>)]) -> HashMap<String, OwnedVariant> {
        list.iter()
            .map(|(k, v)| ((*k).to_owned(), v.try_to_owned().unwrap()))
            .collect()
    }

    fn device(name: &str, powered: bool) -> (String, HashMap<String, OwnedVariant>) {
        let list = [("Name", name.into()), ("Powered", powered.into())];
        (DEVICE.to_owned(), props(&list))
    }

    fn station(scanning: bool) -> (String, HashMap<String, OwnedVariant>) {
        (STATION.to_owned(), props(&[("Scanning", scanning.into())]))
    }

    fn network(
        name: &str,
        kind: &str,
        known: bool,
        connected: bool,
    ) -> (String, HashMap<String, OwnedVariant>) {
        let mut list = vec![
            ("Name", name.into()),
            ("Type", kind.into()),
            ("Connected", connected.into()),
        ];
        if known {
            list.push(("KnownNetwork", Variant::from(path("/net/connman/iwd/x"))));
        }
        (NETWORK.to_owned(), props(&list))
    }

    fn all() -> Objects {
        HashMap::from([
            (
                path(STATION_PATH),
                HashMap::from([device("wlan0", true), station(false)]),
            ),
            (
                path(HOME),
                HashMap::from([network("home", "psk", true, true)]),
            ),
            (
                path(CAFE),
                HashMap::from([network("cafe", "open", false, false)]),
            ),
        ])
    }

    fn line(state: &State) -> String {
        let (tx, rx) = watch::channel(Topics::new());
        crate::server::publish(&tx, "wifi", state);
        rx.borrow()["wifi"].clone()
    }

    const FULL: &str = r#"{"wifi":{"device":"wlan0","powered":true,"scanning":false,"networks":[{"path":"/net/connman/iwd/0/3/home_psk","name":"home","type":"psk","known":true,"connected":true,"dbm":-59}]}}"#;
    const NONE: &str = r#"{"wifi":{"device":null,"powered":false,"scanning":false,"networks":[]}}"#;

    #[test]
    fn serializes_to_the_protocol() {
        assert_eq!(line(&state(&all(), &[(path(HOME), -5900)])), FULL);
        assert_eq!(line(&State::default()), NONE);
    }

    #[test]
    fn keeps_the_order_of_iwd() {
        let s = state(&all(), &[(path(CAFE), -5000), (path(HOME), -7010)]);
        let names: Vec<_> = s.networks.iter().map(|n| (&*n.name, n.dbm)).collect();
        assert_eq!(names, [("cafe", -50), ("home", -70)]);
        assert!(!s.networks[0].known && !s.networks[0].connected);
        assert_eq!(s.networks[0].kind, "open");
    }

    #[test]
    fn network_without_object_is_skipped() {
        let s = state(&all(), &[(path("/gone"), -5000), (path(HOME), -5900)]);
        assert_eq!(line(&s), FULL);
    }

    #[test]
    fn scanning() {
        let mut objects = all();
        let here = objects.get_mut(&path(STATION_PATH)).unwrap();
        here.extend([station(true)]);
        assert!(state(&objects, &[]).scanning);
    }

    #[test]
    fn off_has_a_device_only() {
        let objects =
            HashMap::from([(path(STATION_PATH), HashMap::from([device("wlan0", false)]))]);
        let s = state(&objects, &[]);
        assert_eq!(s.device.as_deref(), Some("wlan0"));
        assert!(!s.powered && !s.scanning && s.networks.is_empty());
    }

    #[test]
    fn no_device() {
        assert_eq!(state(&HashMap::new(), &[]), State::default());
    }

    #[test]
    fn two_devices_give_the_same_one_every_time() {
        for _ in 0..20 {
            let mut objects = all();
            objects.insert(
                path("/net/connman/iwd/1/4"),
                HashMap::from([device("wlan1", false)]),
            );
            assert_eq!(state(&objects, &[]).device.as_deref(), Some("wlan0"));
        }
    }

    #[test]
    fn wrong_types_do_not_panic() {
        let mut objects = all();
        let here = objects.get_mut(&path(STATION_PATH)).unwrap();
        here.insert(DEVICE.to_owned(), props(&[("Name", 5u32.into())]));
        assert_eq!(state(&objects, &[]), State::default());
    }

    // an iwd of our own on the private bus of `run-tests`
    mod on_a_bus {
        use super::*;
        use serde_json::json;
        use std::sync::{Arc, Mutex};
        use tokio::time::{sleep, timeout};
        use zbus::message::Header;

        // one bus name, so one test at a time
        static BUS: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
        const LONG: Duration = Duration::from_secs(5);

        #[derive(Clone, Copy, Default, PartialEq)]
        enum Connects {
            #[default]
            Well,
            Never,
            Hangs,
        }

        #[derive(Default)]
        struct Iwd {
            scanning: bool,
            connects: Connects,
            /// The network it asks the agent about, when not the right one.
            asks: Option<OwnedObjectPath>,
            /// Bus name and path.
            agents: Vec<(String, OwnedObjectPath)>,
            /// What the agent said, per Connect.
            heard: Vec<Result<String, String>>,
            calls: Vec<String>,
            no_device: bool,
        }

        #[derive(Clone, Default)]
        struct Shared(Arc<Mutex<Iwd>>);

        struct FakeObjects(Shared);
        #[zbus::interface(name = "org.freedesktop.DBus.ObjectManager")]
        impl FakeObjects {
            fn get_managed_objects(&self) -> Objects {
                if self.0.0.lock().unwrap().no_device {
                    return Objects::new();
                }
                let mut objects = all();
                let here = objects.get_mut(&path(STATION_PATH)).unwrap();
                here.extend([station(self.0.0.lock().unwrap().scanning)]);
                objects
            }
        }

        struct FakeStation(Shared);
        #[zbus::interface(name = "net.connman.iwd.Station")]
        impl FakeStation {
            fn get_ordered_networks(&self) -> Vec<(OwnedObjectPath, i16)> {
                vec![(path(HOME), -5900)]
            }
            fn scan(&self) {
                self.0.log("Scan");
            }
            fn disconnect(&self) {
                self.0.log("Disconnect");
            }
        }

        struct FakeDevice(Shared);
        #[zbus::interface(name = "net.connman.iwd.Device")]
        impl FakeDevice {
            #[zbus(property)]
            fn powered(&self) -> bool {
                true
            }
            #[zbus(property)]
            fn set_powered(&self, on: bool) {
                self.0.log(&format!("Powered {on}"));
            }
        }

        #[derive(Debug, zbus::DBusError)]
        #[zbus(prefix = "net.connman.iwd")]
        enum FakeError {
            Failed,
            AlreadyExists,
        }

        struct FakeManager(Shared);
        #[zbus::interface(name = "net.connman.iwd.AgentManager")]
        impl FakeManager {
            fn register_agent(
                &self,
                agent: OwnedObjectPath,
                #[zbus(header)] header: Header<'_>,
            ) -> Result<(), FakeError> {
                let mut iwd = self.0.0.lock().unwrap();
                let sender = header.sender().unwrap().to_string();
                if iwd.agents.iter().any(|(s, _)| *s == sender) {
                    return Err(FakeError::AlreadyExists);
                }
                iwd.agents.push((sender, agent));
                Ok(())
            }
            fn unregister_agent(&self, agent: OwnedObjectPath, #[zbus(header)] header: Header<'_>) {
                let sender = header.sender().unwrap().to_string();
                let mut iwd = self.0.0.lock().unwrap();
                iwd.agents.retain(|a| *a != (sender.clone(), agent.clone()));
            }
        }

        struct FakeNetwork(Shared, &'static str);
        #[zbus::interface(name = "net.connman.iwd.Network")]
        impl FakeNetwork {
            async fn connect(
                &self,
                #[zbus(header)] header: Header<'_>,
                #[zbus(connection)] conn: &Connection,
            ) -> Result<(), FakeError> {
                let sender = header.sender().unwrap().to_string();
                let (agent, asked, connects) = {
                    let iwd = self.0.0.lock().unwrap();
                    let agent = iwd.agents.iter().find(|(s, _)| *s == sender).cloned();
                    let asked = iwd.asks.clone().unwrap_or_else(|| path(self.1));
                    (agent, asked, iwd.connects)
                };
                self.0.log("Connect");
                if let Some((name, agent)) = agent {
                    let interface = Some("net.connman.iwd.Agent");
                    let said = conn
                        .call_method(Some(name), agent, interface, "RequestPassphrase", &asked)
                        .await
                        .map(|m| m.body().deserialize::<String>().unwrap())
                        .map_err(|e| match e {
                            zbus::Error::MethodError(name, ..) => name.to_string(),
                            other => other.to_string(),
                        });
                    let refused = said.is_err();
                    self.0.0.lock().unwrap().heard.push(said);
                    if refused {
                        return Err(FakeError::Failed);
                    }
                }
                match connects {
                    Connects::Well => Ok(()),
                    Connects::Never => Err(FakeError::Failed),
                    Connects::Hangs => std::future::pending().await,
                }
            }
        }

        impl Shared {
            fn log(&self, call: &str) {
                self.0.lock().unwrap().calls.push(call.to_owned());
            }
            fn calls(&self) -> Vec<String> {
                self.0.lock().unwrap().calls.clone()
            }
            fn heard(&self) -> Vec<Result<String, String>> {
                self.0.lock().unwrap().heard.clone()
            }
            fn set(&self, change: impl FnOnce(&mut Iwd)) {
                change(&mut self.0.lock().unwrap());
            }
            async fn until(&self, wanted: impl Fn(&Iwd) -> bool) {
                timeout(Duration::from_secs(1), async {
                    while !wanted(&self.0.lock().unwrap()) {
                        sleep(Duration::from_millis(5)).await;
                    }
                })
                .await
                .expect("never happened");
            }
        }

        async fn own(shared: &Shared) -> Connection {
            let conn = Connection::session().await.unwrap();
            let server = conn.object_server();
            server.at("/", FakeObjects(shared.clone())).await.unwrap();
            let here = || shared.clone();
            server.at(STATION_PATH, FakeStation(here())).await.unwrap();
            server.at(STATION_PATH, FakeDevice(here())).await.unwrap();
            let manager = FakeManager(here());
            server.at("/net/connman/iwd", manager).await.unwrap();
            for network in [HOME, CAFE] {
                let fake = FakeNetwork(here(), network);
                server.at(network, fake).await.unwrap();
            }
            conn.request_name(NAME).await.unwrap();
            conn
        }

        async fn changed(conn: &Connection) {
            conn.emit_signal(
                None::<&str>,
                STATION_PATH,
                "org.freedesktop.DBus.Properties",
                "PropertiesChanged",
                &(
                    STATION,
                    HashMap::<&str, Variant<'_>>::new(),
                    Vec::<&str>::new(),
                ),
            )
            .await
            .unwrap();
        }

        fn watching() -> watch::Receiver<Topics> {
            let (tx, rx) = watch::channel(Topics::new());
            tokio::spawn(async move {
                let conn = Connection::session().await.unwrap();
                watch(&conn, &tx, LONG).await
            });
            rx
        }

        async fn becomes(rx: &mut watch::Receiver<Topics>, line: &str) {
            let wanted = rx.wait_for(|t| t.get("wifi").is_some_and(|l| l == line));
            timeout(Duration::from_secs(1), wanted)
                .await
                .unwrap_or_else(|_| panic!("never became {line}"))
                .unwrap();
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn publishes_at_start() {
            let _one = BUS.lock().await;
            let _iwd = own(&Shared::default()).await;
            becomes(&mut watching(), FULL).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn follows_a_scan() {
            let _one = BUS.lock().await;
            let shared = Shared::default();
            let iwd = own(&shared).await;
            let mut rx = watching();
            becomes(&mut rx, FULL).await;
            shared.0.lock().unwrap().scanning = true;
            changed(&iwd).await;
            becomes(
                &mut rx,
                &FULL.replace(r#""scanning":false"#, r#""scanning":true"#),
            )
            .await;
            shared.0.lock().unwrap().scanning = false;
            changed(&iwd).await;
            becomes(&mut rx, FULL).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn follows_new_objects() {
            let _one = BUS.lock().await;
            let shared = Shared::default();
            let iwd = own(&shared).await;
            let mut rx = watching();
            becomes(&mut rx, FULL).await;
            shared.0.lock().unwrap().scanning = true;
            let body = (path(STATION_PATH), Interfaces::new());
            iwd.emit_signal(None::<&str>, "/", OBJECTS, "InterfacesAdded", &body)
                .await
                .unwrap();
            becomes(
                &mut rx,
                &FULL.replace(r#""scanning":false"#, r#""scanning":true"#),
            )
            .await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn empty_when_iwd_is_missing() {
            let _one = BUS.lock().await;
            becomes(&mut watching(), NONE).await;
        }

        async fn wifi(limit: Duration) -> Wifi {
            Wifi::new(Connection::session().await.unwrap(), limit)
        }

        fn join(passphrase: &str) -> Value {
            json!({ "path": HOME, "passphrase": passphrase })
        }

        fn err(code: &str) -> Answer {
            Err(code.to_owned())
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn passphrase_reaches_iwd() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            let _conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            assert_eq!(wifi.call("connect", &join("first one")).await, Ok(()));
            assert_eq!(wifi.call("connect", &join("second one")).await, Ok(()));
            let said = ["first one", "second one"].map(|s| Ok(s.to_owned()));
            assert_eq!(iwd.heard(), said);
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn known_network_needs_no_agent() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            let _conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            for args in [json!({ "path": HOME }), join("")] {
                assert_eq!(wifi.call("connect", &args).await, Ok(()));
            }
            assert_eq!(iwd.calls(), ["Connect", "Connect"]);
            assert!(iwd.heard().is_empty());
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn agent_refuses_other_networks() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.asks = Some(path(CAFE)));
            let _conn = own(&iwd).await;
            let answer = wifi(LONG).await.call("connect", &join("secret")).await;
            assert_eq!(answer, err("Failed"));
            let canceled = "net.connman.iwd.Agent.Error.Canceled".to_owned();
            assert_eq!(iwd.heard(), [Err(canceled)]);
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn agent_is_gone_after_connect() {
            let _one = BUS.lock().await;
            for connects in [Connects::Well, Connects::Never, Connects::Hangs] {
                let iwd = Shared::default();
                iwd.set(|i| i.connects = connects);
                let conn = own(&iwd).await;
                let wifi = wifi(Duration::from_millis(200)).await;
                let _ = wifi.call("connect", &join("secret")).await;
                iwd.until(|i| i.agents.is_empty()).await;
                let name = wifi.conn.unique_name().unwrap().as_str();
                let interface = Some("net.connman.iwd.Agent");
                let home = path(HOME);
                let asked = conn.call_method(
                    Some(name),
                    "/net/kaerice/agent",
                    interface,
                    "RequestPassphrase",
                    &home,
                );
                let asked = timeout(Duration::from_secs(1), asked).await.unwrap();
                assert!(asked.is_err(), "{asked:?}");
            }
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn second_connect_is_busy() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.connects = Connects::Hangs);
            let _conn = own(&iwd).await;
            let wifi = wifi(Duration::from_millis(500)).await;
            let first = tokio::spawn({
                let wifi = wifi.clone();
                async move { wifi.call("connect", &join("first one")).await }
            });
            iwd.until(|i| !i.heard.is_empty()).await;
            let second = wifi.call("connect", &join("second one")).await;
            assert_eq!(second, err("Busy"));
            assert_eq!(first.await.unwrap(), err("Timeout"));
            assert_eq!(iwd.heard(), [Ok("first one".to_owned())]);
            // and free again
            iwd.set(|i| i.connects = Connects::Well);
            assert_eq!(wifi.call("connect", &join("third one")).await, Ok(()));
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn iwd_error_becomes_a_code() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.connects = Connects::Never);
            let _conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            for args in [json!({ "path": HOME }), join("secret")] {
                assert_eq!(wifi.call("connect", &args).await, err("Failed"));
            }
            let missing = json!({ "path": "/net/connman/iwd/0/3/gone_psk" });
            let answer = wifi.call("connect", &missing).await;
            assert_eq!(answer, err("UnknownObject"));
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn unavailable_without_iwd() {
            let _one = BUS.lock().await;
            let wifi = wifi(LONG).await;
            for (what, args) in [
                ("scan", Value::Null),
                ("disconnect", Value::Null),
                ("power", json!({ "on": true })),
                ("connect", join("secret")),
                ("connect", json!({ "path": HOME })),
            ] {
                let answer = wifi.call(what, &args).await;
                assert_eq!(answer, err("Unavailable"), "{what}");
            }
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn unavailable_without_a_device() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.no_device = true);
            let _conn = own(&iwd).await;
            let answer = wifi(LONG).await.call("scan", &Value::Null).await;
            assert_eq!(answer, err("Unavailable"));
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn iwd_that_stops_during_a_connect_is_unavailable() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.connects = Connects::Hangs);
            let conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            let first = tokio::spawn({
                let wifi = wifi.clone();
                async move { wifi.call("connect", &join("secret")).await }
            });
            iwd.until(|i| !i.heard.is_empty()).await;
            conn.close().await.unwrap();
            assert_eq!(first.await.unwrap(), err("Unavailable"));
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn hung_iwd_times_out() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            iwd.set(|i| i.connects = Connects::Hangs);
            let _conn = own(&iwd).await;
            let wifi = wifi(Duration::from_millis(100)).await;
            for args in [json!({ "path": HOME }), join("secret")] {
                let answer = timeout(Duration::from_secs(1), wifi.call("connect", &args)).await;
                assert_eq!(answer, Ok(err("Timeout")));
            }
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn bad_args() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            let _conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            for (what, args) in [
                ("connect", Value::Null),
                ("connect", json!({ "path": "no path" })),
                ("connect", json!({ "path": 5 })),
                ("power", json!({})),
                ("power", json!({ "on": "yes" })),
            ] {
                let answer = wifi.call(what, &args).await;
                assert_eq!(answer, err("InvalidArgs"), "{what}");
            }
            let answer = wifi.call("fly", &Value::Null).await;
            assert_eq!(answer, err("UnknownCall"));
            assert!(iwd.calls().is_empty());
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn scan_disconnect_and_power() {
            let _one = BUS.lock().await;
            let iwd = Shared::default();
            let _conn = own(&iwd).await;
            let wifi = wifi(LONG).await;
            for (what, args) in [
                ("scan", Value::Null),
                ("disconnect", json!({})),
                ("power", json!({ "on": false })),
                ("power", json!({ "on": true })),
            ] {
                assert_eq!(wifi.call(what, &args).await, Ok(()), "{what}");
            }
            let calls = ["Scan", "Disconnect", "Powered false", "Powered true"];
            assert_eq!(iwd.calls(), calls);
        }
    }
}
