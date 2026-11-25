use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde::Serialize;
use tokio::sync::watch;
use zbus::message::Type::Signal;
use zbus::{Connection, MatchRule, OwnedFd, OwnedVariant};

use crate::follow::{call, follow};
use crate::server::{Answer, Topics, publish};

const NAME: &str = "org.freedesktop.login1";
const PATH: &str = "/org/freedesktop/login1";
const MANAGER: &str = "org.freedesktop.login1.Manager";
const PROPERTIES: &str = "org.freedesktop.DBus.Properties";

#[derive(Serialize)]
struct State {
    preparing: bool,
}

#[derive(Default)]
struct Guard {
    preparing: bool,
    /// logind waits for it before it sleeps, 5 s at most.
    inhibitor: Option<OwnedFd>,
}

/// Holds every suspend until the shell has locked the screen.
#[derive(Clone)]
pub struct Sleep {
    conn: Connection,
    guard: Arc<Mutex<Guard>>,
}

impl Sleep {
    pub fn new(conn: Connection) -> Sleep {
        Sleep {
            conn,
            guard: Arc::default(),
        }
    }

    /// Keeps the "sleep" topic up to date: null while nothing holds a suspend, so that the shell does it itself.
    /// Ends only when the bus connection is lost.
    pub async fn watch(&self, tx: &watch::Sender<Topics>, timeout: Duration) -> zbus::Result<()> {
        let prepare = MatchRule::builder()
            .msg_type(Signal)
            .sender(NAME)
            .interface(MANAGER)
            .member("PrepareForSleep")
            .build()?;
        follow(
            &self.conn,
            NAME,
            vec![prepare],
            timeout,
            || self.read(),
            |state| publish(tx, "sleep", &state),
        )
        .await
    }

    async fn read(&self) -> zbus::Result<State> {
        let get = (MANAGER, "PreparingForSleep");
        let value: OwnedVariant = call(&self.conn, NAME, PATH, PROPERTIES, "Get", &get).await?;
        let preparing = value
            .downcast_ref()
            .map_err(|_| zbus::Error::InvalidReply)?;
        let held = {
            let mut guard = self.guard.lock().unwrap();
            guard.preparing = preparing;
            guard.inhibitor.is_some()
        };
        // logind refuses a new inhibitor while it prepares
        if !preparing && !held {
            let body = ("sleep", "kaerice", "Lock the screen before sleep", "delay");
            let inhibitor = call(&self.conn, NAME, PATH, MANAGER, "Inhibit", &body).await?;
            self.guard.lock().unwrap().inhibitor = Some(inhibitor);
        }
        Ok(State { preparing })
    }

    /// `what`: the part of the name after "sleep."
    pub fn call(&self, what: &str) -> Answer {
        if what != "ready" {
            return Err("UnknownCall".into());
        }
        let mut guard = self.guard.lock().unwrap();
        // one that comes after the resume must not let the next suspend through
        if guard.preparing {
            guard.inhibitor = None;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // a logind of our own on the private bus of `run-tests`
    mod on_a_bus {
        use super::*;
        use crate::follow::LOGIND;
        use std::io::{ErrorKind, Read};
        use std::os::fd::OwnedFd as StdFd;
        use std::os::unix::net::UnixStream;
        use tokio::time::{sleep, timeout};

        const LONG: Duration = Duration::from_secs(5);
        // the lines tests/tst_lock.qml checks
        const AWAKE: &str = r#"{"sleep":{"preparing":false}}"#;
        const PREPARING: &str = r#"{"sleep":{"preparing":true}}"#;
        const UNGUARDED: &str = r#"{"sleep":null}"#;

        #[derive(Debug, zbus::DBusError)]
        #[zbus(prefix = "org.freedesktop.DBus.Error")]
        enum FakeError {
            AccessDenied,
        }

        #[derive(Default)]
        struct Logind {
            preparing: bool,
            refuses: bool,
            asked: Vec<[String; 4]>,
            /// Our end of every inhibitor: it reads as closed once the other end is dropped.
            ends: Vec<UnixStream>,
        }

        #[derive(Clone, Default)]
        struct Shared(Arc<Mutex<Logind>>);

        #[zbus::interface(name = "org.freedesktop.login1.Manager")]
        impl Shared {
            fn inhibit(
                &self,
                what: String,
                who: String,
                why: String,
                mode: String,
            ) -> Result<OwnedFd, FakeError> {
                let mut logind = self.0.lock().unwrap();
                logind.asked.push([what, who, why, mode]);
                if logind.refuses {
                    return Err(FakeError::AccessDenied);
                }
                let (ours, theirs) = UnixStream::pair().unwrap();
                ours.set_nonblocking(true).unwrap();
                logind.ends.push(ours);
                Ok(StdFd::from(theirs).into())
            }
            #[zbus(property)]
            fn preparing_for_sleep(&self) -> bool {
                self.0.lock().unwrap().preparing
            }
        }

        impl Shared {
            fn held(&self) -> usize {
                let logind = self.0.lock().unwrap();
                let open = |mut end: &UnixStream| {
                    end.read(&mut [0])
                        .is_err_and(|e| e.kind() == ErrorKind::WouldBlock)
                };
                logind.ends.iter().filter(|end| open(end)).count()
            }
            fn asked(&self) -> usize {
                self.0.lock().unwrap().asked.len()
            }
            async fn until_held(&self, wanted: usize) {
                timeout(Duration::from_secs(1), async {
                    while self.held() != wanted {
                        sleep(Duration::from_millis(5)).await;
                    }
                })
                .await
                .unwrap_or_else(|_| panic!("held {}, not {wanted}", self.held()));
            }
            /// What logind does around a suspend.
            async fn prepare(&self, conn: &Connection, start: bool) {
                self.0.lock().unwrap().preparing = start;
                conn.emit_signal(
                    None::<&str>,
                    PATH,
                    "org.freedesktop.login1.Manager",
                    "PrepareForSleep",
                    &start,
                )
                .await
                .unwrap();
            }
        }

        async fn own(shared: &Shared) -> Connection {
            let conn = Connection::session().await.unwrap();
            conn.object_server().at(PATH, shared.clone()).await.unwrap();
            conn.request_name(NAME).await.unwrap();
            conn
        }

        async fn start() -> (Sleep, watch::Receiver<Topics>) {
            let (tx, rx) = watch::channel(Topics::new());
            let sleep = Sleep::new(Connection::session().await.unwrap());
            let here = sleep.clone();
            tokio::spawn(async move { here.watch(&tx, LONG).await });
            (sleep, rx)
        }

        async fn becomes(rx: &mut watch::Receiver<Topics>, line: &str) {
            let wanted = rx.wait_for(|t| t.get("sleep").is_some_and(|l| l == line));
            timeout(Duration::from_secs(1), wanted)
                .await
                .unwrap_or_else(|_| panic!("never became {line}"))
                .unwrap();
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn holds_and_publishes() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            let _logind = own(&shared).await;
            let (_here, mut rx) = start().await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(shared.held(), 1);
            let asked = shared.0.lock().unwrap().asked[0].clone();
            let why = "Lock the screen before sleep";
            assert_eq!(asked, ["sleep", "kaerice", why, "delay"]);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn ready_lets_it_sleep() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            let logind = own(&shared).await;
            let (here, mut rx) = start().await;
            becomes(&mut rx, AWAKE).await;
            shared.prepare(&logind, true).await;
            becomes(&mut rx, PREPARING).await;
            assert_eq!(shared.held(), 1, "it must wait for the lock screen");
            assert_eq!(here.call("ready"), Ok(()));
            shared.until_held(0).await;
            shared.prepare(&logind, false).await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(shared.held(), 1, "the next suspend must wait again");
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn late_ready_keeps_the_hold() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            let logind = own(&shared).await;
            let (here, mut rx) = start().await;
            becomes(&mut rx, AWAKE).await;
            shared.prepare(&logind, true).await;
            becomes(&mut rx, PREPARING).await;
            shared.prepare(&logind, false).await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(here.call("ready"), Ok(()));
            assert_eq!(shared.held(), 1);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn one_hold_only() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            let logind = own(&shared).await;
            let (_here, mut rx) = start().await;
            becomes(&mut rx, AWAKE).await;
            shared.prepare(&logind, true).await;
            becomes(&mut rx, PREPARING).await;
            shared.prepare(&logind, false).await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(shared.asked(), 1);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn starts_during_a_suspend() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            shared.0.lock().unwrap().preparing = true;
            let logind = own(&shared).await;
            let (_here, mut rx) = start().await;
            becomes(&mut rx, PREPARING).await;
            assert_eq!(shared.asked(), 0, "logind refuses it now");
            shared.prepare(&logind, false).await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(shared.held(), 1);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn refused_is_null() {
            let _one = LOGIND.lock().await;
            let shared = Shared::default();
            shared.0.lock().unwrap().refuses = true;
            let _logind = own(&shared).await;
            let (_here, mut rx) = start().await;
            becomes(&mut rx, UNGUARDED).await;
            assert_eq!(shared.asked(), 1);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn null_without_logind_and_back() {
            let _one = LOGIND.lock().await;
            let (_here, mut rx) = start().await;
            becomes(&mut rx, UNGUARDED).await;
            let shared = Shared::default();
            let _logind = own(&shared).await;
            becomes(&mut rx, AWAKE).await;
            assert_eq!(shared.held(), 1);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn unknown_call() {
            let (here, _rx) = start().await;
            assert_eq!(here.call("now"), Err("UnknownCall".into()));
        }
    }
}
