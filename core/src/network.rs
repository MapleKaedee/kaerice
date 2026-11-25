use std::future::poll_fn;
use std::pin::Pin;
use std::time::Duration;

use serde::Serialize;
use serde_json::Value;
use tokio::sync::{Notify, watch};
use tokio::time;
use zbus::export::futures_core::Stream;
use zbus::message::Type::Signal;
use zbus::proxy::MethodFlags;
use zbus::{Connection, MatchRule, MessageStream, Proxy};

use crate::server::{Topics, publish};

const NAME: &str = "org.freedesktop.network1";
const PATH: &str = "/org/freedesktop/network1";
const OFFLINE: Status = Status {
    kind: Kind::Offline,
    ssid: None,
};
/// One change sends several signals.
const JOIN: Duration = Duration::from_millis(200);

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    Eth,
    Wifi,
    Offline,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Status {
    pub kind: Kind,
    pub ssid: Option<String>,
}

/// networkd's Describe JSON (the same shape as `networkctl list --json`) to what the shell shows.
pub fn status(describe: &str) -> Status {
    let json: Value = serde_json::from_str(describe).unwrap_or_default();
    let up = |kind: &str| {
        json["Interfaces"]
            .as_array()?
            .iter()
            .find(|i| i["Type"] == kind && i["OperationalState"] == "routable")
    };
    if up("ether").is_some() {
        return Status {
            kind: Kind::Eth,
            ssid: None,
        };
    }
    match up("wlan") {
        Some(wifi) => Status {
            kind: Kind::Wifi,
            ssid: wifi["SSID"].as_str().map(str::to_owned),
        },
        None => OFFLINE,
    }
}

/// Keeps the "network" topic up to date. Ends only when the bus connection is lost.
pub async fn watch(
    conn: &Connection,
    tx: &watch::Sender<Topics>,
    timeout: Duration,
) -> zbus::Result<()> {
    let mut changes = MessageStream::for_match_rule(
        MatchRule::builder()
            .msg_type(Signal)
            .sender(NAME)
            .interface("org.freedesktop.DBus.Properties")
            .member("PropertiesChanged")
            .path_namespace(PATH)
            .build()?,
        conn,
        None,
    )
    .await?;
    let mut owners = MessageStream::for_match_rule(
        MatchRule::builder()
            .msg_type(Signal)
            .sender("org.freedesktop.DBus")
            .interface("org.freedesktop.DBus")
            .member("NameOwnerChanged")
            .arg(0, NAME)
            .build()?,
        conn,
        None,
    )
    .await?;

    let dirty = Notify::new();
    // apart from the reads: a stream that nobody polls stalls the connection, the reply to Describe included
    let pump = async {
        loop {
            let ended = tokio::select! {
                m = next(&mut changes) => m.is_none(),
                m = next(&mut owners) => m.is_none(),
            };
            if ended {
                return;
            }
            dirty.notify_one();
        }
    };
    let reads = async {
        let mut failed = false;
        loop {
            let answer = read(conn, timeout).await;
            let retry = answer.as_ref().is_err_and(|e| !gone(e));
            if let Err(e) = &answer
                && !failed
            {
                eprintln!("kaericed: networkd: {e}");
            }
            failed = answer.is_err();
            publish(tx, "network", &answer.unwrap_or(OFFLINE));
            if retry {
                let _ = time::timeout(timeout, dirty.notified()).await;
            } else {
                dirty.notified().await;
            }
            time::sleep(JOIN).await;
        }
    };
    tokio::select! {
        () = pump => {}
        () = reads => {}
    }
    Err(zbus::Error::Failure("the bus connection was lost".into()))
}

async fn next(stream: &mut MessageStream) -> Option<zbus::Result<zbus::Message>> {
    poll_fn(|cx| Pin::new(&mut *stream).poll_next(cx)).await
}

async fn read(conn: &Connection, timeout: Duration) -> zbus::Result<Status> {
    let answer = time::timeout(timeout, describe(conn)).await;
    let json = answer.map_err(|_| zbus::Error::Failure("no answer".into()))??;
    Ok(status(&json))
}

/// Not on the bus. Its return is a signal, so there is nothing to retry.
fn gone(error: &zbus::Error) -> bool {
    use zbus::fdo::Error::{NameHasNoOwner, ServiceUnknown};
    matches!(error, zbus::Error::FDO(e) if matches!(**e, NameHasNoOwner(_) | ServiceUnknown(_)))
}

// NoAutoStart: a networkd that the user stopped stays stopped
async fn describe(conn: &Connection) -> zbus::Result<String> {
    Proxy::new(conn, NAME, PATH, "org.freedesktop.network1.Manager")
        .await?
        .call_with_flags("Describe", MethodFlags::NO_AUTO_START, &())
        .await?
        .ok_or(zbus::Error::InvalidReply)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn link(kind: &str, state: &str, ssid: Option<&str>) -> serde_json::Value {
        let mut v = serde_json::json!({ "Type": kind, "OperationalState": state });
        if let Some(s) = ssid {
            v["SSID"] = s.into();
        }
        v
    }

    fn of(links: &[serde_json::Value]) -> Status {
        status(&serde_json::json!({ "Interfaces": links }).to_string())
    }

    fn wifi(ssid: Option<&str>) -> Status {
        Status {
            kind: Kind::Wifi,
            ssid: ssid.map(str::to_owned),
        }
    }

    #[test]
    fn ethernet_wins_over_wifi() {
        let s = of(&[
            link("wlan", "routable", Some("home")),
            link("ether", "routable", None),
        ]);
        assert_eq!(
            s,
            Status {
                kind: Kind::Eth,
                ssid: None
            }
        );
    }

    #[test]
    fn wifi_with_ssid() {
        assert_eq!(
            of(&[link("wlan", "routable", Some("home"))]),
            wifi(Some("home"))
        );
    }

    #[test]
    fn wifi_without_ssid() {
        assert_eq!(of(&[link("wlan", "routable", None)]), wifi(None));
    }

    #[test]
    fn ethernet_without_carrier_is_ignored() {
        let s = of(&[
            link("ether", "no-carrier", None),
            link("wlan", "routable", Some("home")),
        ]);
        assert_eq!(s, wifi(Some("home")));
    }

    #[test]
    fn degraded_wifi_is_offline() {
        assert_eq!(of(&[link("wlan", "degraded", Some("home"))]), OFFLINE);
    }

    #[test]
    fn loopback_is_offline() {
        assert_eq!(of(&[link("loopback", "routable", None)]), OFFLINE);
    }

    #[test]
    fn unusable_json_is_offline() {
        for text in ["", "{", "[]", r#"{"Interfaces":null}"#] {
            assert_eq!(status(text), OFFLINE, "{text}");
        }
    }

    #[test]
    fn serializes_to_the_protocol() {
        let line = |s| serde_json::to_string(&s).unwrap();
        assert_eq!(line(wifi(Some("home"))), r#"{"kind":"wifi","ssid":"home"}"#);
        assert_eq!(line(OFFLINE), r#"{"kind":"offline","ssid":null}"#);
    }

    // a networkd of our own on the private bus of `run-tests`
    mod on_a_bus {
        use super::*;
        use std::collections::HashMap;
        use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering::SeqCst};
        use std::sync::{Arc, Mutex};
        use tokio::time::{sleep, timeout};
        use zbus::Variant;

        const ETH: &str = r#"{"network":{"kind":"eth","ssid":null}}"#;
        const WIFI: &str = r#"{"network":{"kind":"wifi","ssid":"home"}}"#;
        const OFF: &str = r#"{"network":{"kind":"offline","ssid":null}}"#;
        const ETH_JSON: &str = r#"{"Interfaces":[{"Type":"ether","OperationalState":"routable"}]}"#;
        const WIFI_JSON: &str =
            r#"{"Interfaces":[{"Type":"wlan","OperationalState":"routable","SSID":"home"}]}"#;

        // one bus name, so one test at a time
        static BUS: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

        #[derive(Clone, Default)]
        struct Fake {
            json: Arc<Mutex<String>>,
            calls: Arc<AtomicUsize>,
            hangs: Arc<AtomicBool>,
        }

        #[zbus::interface(name = "org.freedesktop.network1.Manager")]
        impl Fake {
            async fn describe(&self) -> String {
                self.calls.fetch_add(1, SeqCst);
                if self.hangs.load(SeqCst) {
                    std::future::pending::<()>().await;
                }
                self.json.lock().unwrap().clone()
            }
        }

        impl Fake {
            fn says(json: &str) -> Fake {
                let fake = Fake::default();
                fake.now(json);
                fake
            }
            fn now(&self, json: &str) {
                *self.json.lock().unwrap() = json.to_owned();
            }
        }

        async fn own(fake: &Fake) -> Connection {
            let conn = Connection::session().await.unwrap();
            conn.object_server().at(PATH, fake.clone()).await.unwrap();
            conn.request_name(NAME).await.unwrap();
            conn
        }

        async fn signal(conn: &Connection) {
            conn.emit_signal(
                None::<&str>,
                "/org/freedesktop/network1/link/_31",
                "org.freedesktop.DBus.Properties",
                "PropertiesChanged",
                &(
                    "org.freedesktop.network1.Link",
                    HashMap::<&str, Variant<'_>>::new(),
                    Vec::<&str>::new(),
                ),
            )
            .await
            .unwrap();
        }

        fn watching(limit: Duration) -> watch::Receiver<Topics> {
            let (tx, rx) = watch::channel(Topics::new());
            tokio::spawn(async move {
                let conn = Connection::session().await.unwrap();
                watch(&conn, &tx, limit).await
            });
            rx
        }

        async fn becomes(rx: &mut watch::Receiver<Topics>, line: &str) {
            let wanted = rx.wait_for(|t| t.get("network").is_some_and(|l| l == line));
            timeout(Duration::from_secs(1), wanted)
                .await
                .unwrap_or_else(|_| panic!("never became {line}"))
                .unwrap();
        }

        const LONG: Duration = Duration::from_secs(5);

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn publishes_at_start() {
            let _one = BUS.lock().await;
            let _networkd = own(&Fake::says(WIFI_JSON)).await;
            becomes(&mut watching(LONG), WIFI).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn follows_properties_changed() {
            let _one = BUS.lock().await;
            let fake = Fake::says(WIFI_JSON);
            let networkd = own(&fake).await;
            let mut rx = watching(LONG);
            becomes(&mut rx, WIFI).await;
            fake.now(ETH_JSON);
            signal(&networkd).await;
            becomes(&mut rx, ETH).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn joins_bursts() {
            let _one = BUS.lock().await;
            let fake = Fake::says(WIFI_JSON);
            let networkd = own(&fake).await;
            let mut rx = watching(LONG);
            becomes(&mut rx, WIFI).await;
            let before = fake.calls.load(SeqCst);
            for _ in 0..20 {
                signal(&networkd).await;
                sleep(Duration::from_millis(5)).await;
            }
            sleep(Duration::from_millis(800)).await;
            let reads = fake.calls.load(SeqCst) - before;
            assert!((1..=2).contains(&reads), "{reads} reads");
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn offline_when_networkd_is_missing() {
            let _one = BUS.lock().await;
            becomes(&mut watching(LONG), OFF).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn follows_networkd_restart() {
            let _one = BUS.lock().await;
            let networkd = own(&Fake::says(WIFI_JSON)).await;
            let mut rx = watching(LONG);
            becomes(&mut rx, WIFI).await;
            networkd.release_name(NAME).await.unwrap();
            becomes(&mut rx, OFF).await;
            networkd.request_name(NAME).await.unwrap();
            becomes(&mut rx, WIFI).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn offline_when_describe_hangs() {
            let _one = BUS.lock().await;
            let fake = Fake::says(WIFI_JSON);
            fake.hangs.store(true, SeqCst);
            let _networkd = own(&fake).await;
            becomes(&mut watching(Duration::from_millis(100)), OFF).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn recovers_from_a_hang_without_a_signal() {
            let _one = BUS.lock().await;
            let fake = Fake::says(WIFI_JSON);
            fake.hangs.store(true, SeqCst);
            let _networkd = own(&fake).await;
            let mut rx = watching(Duration::from_millis(100));
            becomes(&mut rx, OFF).await;
            fake.hangs.store(false, SeqCst);
            becomes(&mut rx, WIFI).await;
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn only_a_missing_networkd_is_gone() {
            let _one = BUS.lock().await;
            let conn = Connection::session().await.unwrap();
            let missing = read(&conn, LONG).await.unwrap_err();
            assert!(gone(&missing), "{missing:?}");
            let fake = Fake::says(WIFI_JSON);
            fake.hangs.store(true, SeqCst);
            let _networkd = own(&fake).await;
            let hung = read(&conn, Duration::from_millis(100)).await.unwrap_err();
            assert!(!gone(&hung), "{hung:?}");
        }

        #[tokio::test]
        #[ignore = "needs a private bus"]
        async fn signals_during_describe_do_not_block_it() {
            let _one = BUS.lock().await;
            let fake = Fake::says(WIFI_JSON);
            fake.hangs.store(true, SeqCst);
            let networkd = own(&fake).await;
            let mut rx = watching(Duration::from_millis(300));
            timeout(LONG, async {
                while fake.calls.load(SeqCst) == 0 {
                    sleep(Duration::from_millis(5)).await;
                }
            })
            .await
            .expect("Describe was never called");
            for _ in 0..200 {
                signal(&networkd).await;
            }
            fake.hangs.store(false, SeqCst);
            becomes(&mut rx, WIFI).await;
        }
    }
}
