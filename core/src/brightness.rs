use std::fs::{self, File};
use std::future::pending;
use std::io;
use std::os::unix::fs::FileExt;
use std::path::{Path, PathBuf};
use std::time::Duration;

use serde::Serialize;
use serde_json::Value;
use tokio::io::Interest;
use tokio::io::unix::AsyncFd;
use tokio::sync::watch;
use tokio::time;
use zbus::Connection;

use crate::follow::{call, code};
use crate::server::{Answer, Topics, publish};

const NAME: &str = "org.freedesktop.login1";
/// The user's session in the foreground: the daemon itself belongs to none.
const PATH: &str = "/org/freedesktop/login1/session/auto";
const SESSION: &str = "org.freedesktop.login1.Session";
/// The order the kernel asks for when there are several.
const KINDS: [&str; 3] = ["firmware", "platform", "raw"];

#[derive(Serialize)]
struct State {
    percent: u32,
}

#[derive(Clone, Debug, PartialEq)]
struct Device {
    dir: PathBuf,
    name: String,
    max: u32,
}

/// `class`: /sys/class/backlight.
fn find(class: &Path) -> Option<Device> {
    let devices = fs::read_dir(class).ok()?.flatten().filter_map(|entry| {
        let dir = entry.path();
        let kind = fs::read_to_string(dir.join("type")).ok()?;
        let rank = KINDS.iter().position(|k| *k == kind.trim());
        let max = number(&dir.join("max_brightness")).ok()?;
        let name = entry.file_name().into_string().ok()?;
        let device = Device { dir, name, max };
        (max > 0).then_some((rank.unwrap_or(KINDS.len()), device))
    });
    let (_, device) = devices.min_by_key(|(rank, device)| (*rank, device.name.clone()))?;
    Some(device)
}

fn number(file: &Path) -> io::Result<u32> {
    let text = fs::read_to_string(file)?;
    text.trim()
        .parse()
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

fn percent(raw: u32, max: u32) -> u32 {
    scale(raw, 100, max).min(100)
}

/// Never 0: that is a black screen.
fn raw(percent: u32, max: u32) -> u32 {
    scale(percent, max, 100).max(1)
}

/// value * to / from, rounded.
fn scale(value: u32, to: u32, from: u32) -> u32 {
    let (value, to, from) = (u64::from(value), u64::from(to), u64::from(from));
    u32::try_from((value * to + from / 2) / from).unwrap_or(u32::MAX)
}

/// The screen backlight: its topic and the "brightness.*" calls.
#[derive(Clone)]
pub struct Brightness {
    conn: Connection,
    tx: watch::Sender<Topics>,
    device: Option<Device>,
    timeout: Duration,
}

impl Brightness {
    pub fn new(
        conn: Connection,
        tx: watch::Sender<Topics>,
        class: &Path,
        timeout: Duration,
    ) -> Brightness {
        Brightness {
            conn,
            tx,
            device: find(class),
            timeout,
        }
    }

    /// Keeps the "brightness" topic up to date. Never ends: a backlight that fails takes nothing else down.
    pub async fn watch(&self) {
        if let Some(device) = &self.device
            && let Err(e) = self.follow(device).await
        {
            eprintln!("kaericed: no backlight events: {e}");
        }
        pending().await
    }

    async fn follow(&self, device: &Device) -> io::Result<()> {
        self.publish(device);
        // the driver signals here, but the value that was asked for is in "brightness"
        let file = File::open(device.dir.join("actual_brightness"))?;
        // SAFETY: the file keeps its descriptor open until it is dropped
        let events = unsafe { AsyncFd::register_with_interest(file, Interest::PRIORITY)? };
        loop {
            // sysfs signals the next change only after a read
            let _ = events.get_ref().read_at(&mut [0; 16], 0);
            self.publish(device);
            events.ready(Interest::PRIORITY).await?.clear_ready();
        }
    }

    fn publish(&self, device: &Device) {
        match number(&device.dir.join("brightness")) {
            Ok(raw) => {
                let percent = percent(raw, device.max);
                publish(&self.tx, "brightness", &State { percent });
            }
            Err(e) => eprintln!("kaericed: backlight: {e}"),
        }
    }

    /// `what`: the part of the name after "brightness."
    pub async fn call(&self, what: &str, args: &Value) -> Answer {
        if what != "set" {
            return Err("UnknownCall".into());
        }
        let percent = args["percent"]
            .as_u64()
            .and_then(|p| u32::try_from(p).ok())
            .filter(|p| (1..=100).contains(p))
            .ok_or("InvalidArgs")?;
        let device = self.device.as_ref().ok_or("Unavailable")?;
        let body = ("backlight", device.name.as_str(), raw(percent, device.max));
        let set = call(&self.conn, NAME, PATH, SESSION, "SetBrightness", &body);
        let () = time::timeout(self.timeout, set)
            .await
            .map_err(|_| "Timeout")?
            .map_err(code)?;
        self.publish(device);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A folder like /sys/class/backlight, removed at the end.
    struct Class(PathBuf);
    impl Class {
        fn new(name: &str) -> Class {
            let dir =
                std::env::temp_dir().join(format!("kaericed-{}-class-{name}", std::process::id()));
            let _ = fs::remove_dir_all(&dir);
            fs::create_dir(&dir).unwrap();
            Class(dir)
        }
        fn with(self, name: &str, kind: &str, raw: &str, max: &str) -> Class {
            let dir = self.0.join(name);
            fs::create_dir(&dir).unwrap();
            for (file, text) in [
                ("type", kind),
                ("brightness", raw),
                ("actual_brightness", raw),
                ("max_brightness", max),
            ] {
                fs::write(dir.join(file), format!("{text}\n")).unwrap();
            }
            self
        }
        fn found(&self) -> Option<String> {
            find(&self.0).map(|d| d.name)
        }
    }
    impl Drop for Class {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn finds_the_device() {
        let class = Class::new("one").with("nvidia_0", "raw", "55", "100");
        let device = Device {
            dir: class.0.join("nvidia_0"),
            name: "nvidia_0".into(),
            max: 100,
        };
        assert_eq!(find(&class.0), Some(device));
    }

    #[test]
    fn firmware_then_platform_then_raw() {
        let class = Class::new("kinds").with("a", "raw", "1", "9");
        assert_eq!(class.found().as_deref(), Some("a"));
        let class = class.with("b", "platform", "1", "9");
        assert_eq!(class.found().as_deref(), Some("b"));
        let class = class.with("c", "firmware", "1", "9");
        assert_eq!(class.found().as_deref(), Some("c"));
        let class = class.with("0", "future", "1", "9");
        assert_eq!(class.found().as_deref(), Some("c"));
    }

    #[test]
    fn same_kind_goes_by_name() {
        for names in [["x", "y"], ["y", "x"]] {
            let class = Class::new("names")
                .with(names[0], "raw", "1", "9")
                .with(names[1], "raw", "1", "9");
            assert_eq!(class.found().as_deref(), Some("x"));
        }
    }

    #[test]
    fn unusable_devices_are_skipped() {
        let class = Class::new("unusable")
            .with("a", "firmware", "0", "0")
            .with("b", "firmware", "1", "x");
        assert_eq!(class.found(), None);
        fs::create_dir(class.0.join("c")).unwrap();
        assert_eq!(class.found(), None);
        let class = class.with("d", "raw", "1", "9");
        assert_eq!(class.found().as_deref(), Some("d"));
    }

    #[test]
    fn no_devices() {
        assert_eq!(find(&Class::new("none").0), None);
        assert_eq!(find(Path::new("/nonexistent")), None);
    }

    #[test]
    fn raw_to_percent() {
        for (raw, max, wanted) in [
            (100, 100, 100),
            (55, 100, 55),
            (0, 100, 0),
            (128, 255, 50),
            (1, 15, 7),
            (19393, 19393, 100),
            (300, 255, 100),
            (u32::MAX, u32::MAX, 100),
        ] {
            assert_eq!(percent(raw, max), wanted, "{raw} of {max}");
        }
    }

    #[test]
    fn percent_to_raw() {
        for (percent, max, wanted) in [
            (100, 100, 100),
            (55, 100, 55),
            (50, 255, 128),
            (100, 15, 15),
            // never black
            (1, 15, 1),
            (1, 1, 1),
            (100, u32::MAX, u32::MAX),
        ] {
            assert_eq!(raw(percent, max), wanted, "{percent}% of {max}");
        }
    }

    // a logind of our own on the private bus of `run-tests`
    mod on_a_bus {
        use super::*;
        use crate::follow::LOGIND as BUS;
        use serde_json::json;
        use tokio::time::timeout;

        const LONG: Duration = Duration::from_secs(5);
        const SHORT: Duration = Duration::from_millis(200);
        const LINE: &str = r#"{"brightness":{"percent":55}}"#;

        #[derive(Debug, zbus::DBusError)]
        #[zbus(prefix = "org.freedesktop.DBus.Error")]
        enum FakeError {
            AccessDenied,
        }

        enum Session {
            /// Writes to this class.
            Writes(PathBuf),
            Refuses,
            Hangs,
        }

        #[zbus::interface(name = "org.freedesktop.login1.Session")]
        impl Session {
            async fn set_brightness(
                &self,
                subsystem: String,
                name: String,
                value: u32,
            ) -> Result<(), FakeError> {
                match self {
                    Session::Writes(class) => {
                        assert_eq!(subsystem, "backlight");
                        fs::write(class.join(name).join("brightness"), format!("{value}\n"))
                            .unwrap();
                        Ok(())
                    }
                    Session::Refuses => Err(FakeError::AccessDenied),
                    Session::Hangs => std::future::pending().await,
                }
            }
        }

        async fn own(session: Session) -> Connection {
            let conn = Connection::session().await.unwrap();
            conn.object_server().at(PATH, session).await.unwrap();
            conn.request_name(NAME).await.unwrap();
            conn
        }

        async fn start(class: &Class, limit: Duration) -> (Brightness, watch::Receiver<Topics>) {
            let (tx, rx) = watch::channel(Topics::new());
            let conn = Connection::session().await.unwrap();
            (Brightness::new(conn, tx, &class.0, limit), rx)
        }

        fn line(rx: &watch::Receiver<Topics>) -> Option<String> {
            rx.borrow().get("brightness").cloned()
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn set_writes_and_publishes() {
            let _bus = BUS.lock().await;
            let class = Class::new("set").with("b", "raw", "255", "255");
            let _logind = own(Session::Writes(class.0.clone())).await;
            let (here, rx) = start(&class, LONG).await;
            assert_eq!(here.call("set", &json!({"percent": 55})).await, Ok(()));
            assert_eq!(
                fs::read_to_string(class.0.join("b/brightness")).unwrap(),
                "140\n"
            );
            assert_eq!(line(&rx).as_deref(), Some(LINE));
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn set_needs_1_to_100() {
            let _bus = BUS.lock().await;
            let class = Class::new("args").with("b", "raw", "50", "100");
            let _logind = own(Session::Writes(class.0.clone())).await;
            let (here, _rx) = start(&class, LONG).await;
            for args in [
                json!({}),
                json!(null),
                json!({"percent": 0}),
                json!({"percent": 101}),
                json!({"percent": -5}),
                json!({"percent": 54.6}),
                json!({"percent": "55"}),
                json!({"percent": u64::MAX}),
            ] {
                let answer = here.call("set", &args).await;
                assert_eq!(answer, Err("InvalidArgs".into()), "{args}");
            }
            let raw = fs::read_to_string(class.0.join("b/brightness")).unwrap();
            assert_eq!(raw, "50\n");
            assert_eq!(
                here.call("get", &json!({})).await,
                Err("UnknownCall".into())
            );
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn set_without_a_backlight() {
            let _bus = BUS.lock().await;
            let class = Class::new("without");
            let _logind = own(Session::Refuses).await;
            let (here, _rx) = start(&class, LONG).await;
            assert_eq!(
                here.call("set", &json!({"percent": 55})).await,
                Err("Unavailable".into())
            );
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn logind_error_becomes_a_code() {
            let _bus = BUS.lock().await;
            let class = Class::new("refuses").with("b", "raw", "50", "100");
            let _logind = own(Session::Refuses).await;
            let (here, _rx) = start(&class, LONG).await;
            assert_eq!(
                here.call("set", &json!({"percent": 55})).await,
                Err("AccessDenied".into())
            );
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn hung_logind_times_out() {
            let _bus = BUS.lock().await;
            let class = Class::new("hangs").with("b", "raw", "50", "100");
            let _logind = own(Session::Hangs).await;
            let (here, _rx) = start(&class, SHORT).await;
            assert_eq!(
                here.call("set", &json!({"percent": 55})).await,
                Err("Timeout".into())
            );
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn unavailable_without_logind() {
            let _bus = BUS.lock().await;
            let class = Class::new("gone").with("b", "raw", "50", "100");
            let (here, _rx) = start(&class, LONG).await;
            assert_eq!(
                here.call("set", &json!({"percent": 55})).await,
                Err("Unavailable".into())
            );
        }

        // epoll refuses a plain file, like a driver without events
        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn watch_publishes_and_does_not_end_without_events() {
            let class = Class::new("plain").with("b", "raw", "55", "100");
            let (here, rx) = start(&class, LONG).await;
            let end = timeout(SHORT, here.watch()).await;
            assert!(end.is_err(), "it ended");
            assert_eq!(line(&rx).as_deref(), Some(LINE));
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn watch_without_a_backlight_publishes_nothing() {
            let class = Class::new("nothing");
            let (here, rx) = start(&class, LONG).await;
            let end = timeout(SHORT, here.watch()).await;
            assert!(end.is_err(), "it ended");
            assert_eq!(line(&rx), None);
        }

        #[tokio::test]
        #[ignore = "needs run-tests"]
        async fn an_unreadable_value_keeps_the_last_one() {
            let class = Class::new("unreadable").with("b", "raw", "55", "100");
            let (here, rx) = start(&class, LONG).await;
            let _ = timeout(SHORT, here.watch()).await;
            fs::remove_file(class.0.join("b/brightness")).unwrap();
            let _ = timeout(SHORT, here.watch()).await;
            assert_eq!(line(&rx).as_deref(), Some(LINE));
        }
    }
}
