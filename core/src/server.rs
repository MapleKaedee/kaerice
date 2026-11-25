use std::collections::BTreeMap;
use std::io;
use std::os::unix::net::UnixStream as Probe;
use std::path::Path;

use serde::Serialize;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::watch;

/// The last state of every topic, as the line that is sent (without the newline).
pub type Topics = BTreeMap<&'static str, String>;

pub fn publish<T: Serialize>(tx: &watch::Sender<Topics>, topic: &'static str, payload: &T) {
    let line =
        serde_json::to_string(&BTreeMap::from([(topic, payload)])).expect("topics are plain data");
    tx.send_if_modified(|topics| topics.insert(topic, line.clone()) != Some(line));
}

pub fn bind(path: &Path) -> io::Result<UnixListener> {
    match UnixListener::bind(path) {
        Err(e) if e.kind() == io::ErrorKind::AddrInUse && Probe::connect(path).is_err() => {
            std::fs::remove_file(path)?;
            UnixListener::bind(path)
        }
        result => result,
    }
}

pub async fn serve(listener: UnixListener, rx: watch::Receiver<Topics>) -> io::Result<()> {
    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(client(stream, rx.clone()));
    }
}

/// Ends when the client leaves.
async fn client(mut stream: UnixStream, mut rx: watch::Receiver<Topics>) -> io::Result<()> {
    let mut sent = Topics::new();
    let mut input = [0; 256];
    loop {
        let topics = rx.borrow_and_update().clone();
        for (topic, line) in &topics {
            if sent.get(topic) != Some(line) {
                stream.write_all(format!("{line}\n").as_bytes()).await?;
            }
        }
        sent = topics;
        tokio::select! {
            changed = rx.changed() => if changed.is_err() { return Ok(()) },
            read = stream.read(&mut input) => if read? == 0 { return Ok(()) },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::network::{Kind, Status};
    use std::path::PathBuf;
    use std::time::Duration;
    use tokio::io::{AsyncBufReadExt, BufReader, Lines};
    use tokio::time::timeout;

    fn state(kind: Kind, ssid: Option<&str>) -> Status {
        Status {
            kind,
            ssid: ssid.map(str::to_owned),
        }
    }

    /// A socket path of its own for each test, removed at the end.
    struct Sock(PathBuf);
    impl Sock {
        fn new(name: &str) -> Sock {
            let path = std::env::temp_dir().join(format!("kaericed-{}-{name}", std::process::id()));
            let _ = std::fs::remove_file(&path);
            Sock(path)
        }
    }
    impl Drop for Sock {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }

    fn start(sock: &Sock) -> watch::Sender<Topics> {
        let (tx, rx) = watch::channel(Topics::new());
        tokio::spawn(serve(bind(&sock.0).unwrap(), rx));
        tx
    }

    async fn connect(sock: &Sock) -> Lines<BufReader<UnixStream>> {
        BufReader::new(UnixStream::connect(&sock.0).await.unwrap()).lines()
    }

    async fn next(lines: &mut Lines<BufReader<UnixStream>>) -> String {
        timeout(Duration::from_secs(2), lines.next_line())
            .await
            .expect("no line in time")
            .unwrap()
            .expect("closed")
    }

    const ETH: &str = r#"{"network":{"kind":"eth","ssid":null}}"#;
    const WIFI: &str = r#"{"network":{"kind":"wifi","ssid":"home"}}"#;
    const OFFLINE: &str = r#"{"network":{"kind":"offline","ssid":null}}"#;

    #[test]
    fn publish_writes_the_protocol_lines() {
        for (status, line) in [
            (state(Kind::Eth, None), ETH),
            (state(Kind::Wifi, Some("home")), WIFI),
            (state(Kind::Offline, None), OFFLINE),
        ] {
            let (tx, rx) = watch::channel(Topics::new());
            publish(&tx, "network", &status);
            assert_eq!(rx.borrow()["network"], line);
        }
    }

    #[test]
    fn same_state_does_not_notify() {
        let (tx, mut rx) = watch::channel(Topics::new());
        publish(&tx, "network", &state(Kind::Eth, None));
        rx.borrow_and_update();
        publish(&tx, "network", &state(Kind::Eth, None));
        assert!(!rx.has_changed().unwrap());
        publish(&tx, "network", &state(Kind::Offline, None));
        assert!(rx.has_changed().unwrap());
    }

    #[tokio::test]
    async fn new_client_gets_state_first() {
        let sock = Sock::new("first");
        let tx = start(&sock);
        publish(&tx, "network", &state(Kind::Eth, None));
        assert_eq!(next(&mut connect(&sock).await).await, ETH);
    }

    #[tokio::test]
    async fn every_client_gets_changes() {
        let sock = Sock::new("every");
        let tx = start(&sock);
        let (mut a, mut b) = (connect(&sock).await, connect(&sock).await);
        publish(&tx, "network", &state(Kind::Wifi, Some("home")));
        assert_eq!(next(&mut a).await, WIFI);
        assert_eq!(next(&mut b).await, WIFI);
    }

    #[tokio::test]
    async fn client_leaving_does_not_stop_server() {
        let sock = Sock::new("leaving");
        let tx = start(&sock);
        publish(&tx, "network", &state(Kind::Eth, None));
        let mut a = connect(&sock).await;
        let mut b = connect(&sock).await;
        next(&mut a).await;
        next(&mut b).await;
        drop(a);
        publish(&tx, "network", &state(Kind::Offline, None));
        assert_eq!(next(&mut b).await, OFFLINE);
    }

    #[tokio::test]
    async fn client_that_never_reads_does_not_block_others() {
        let sock = Sock::new("stuck");
        let tx = start(&sock);
        let _stuck = connect(&sock).await;
        let mut b = connect(&sock).await;
        let long = "x".repeat(4096);
        for i in 0..2000 {
            publish(&tx, "network", &format!("{i}{long}"));
            tokio::task::yield_now().await;
        }
        let last = format!(r#"{{"network":"1999{long}"}}"#);
        while next(&mut b).await != last {}
    }

    #[tokio::test]
    async fn bind_replaces_stale_socket() {
        let sock = Sock::new("stale");
        drop(std::os::unix::net::UnixListener::bind(&sock.0).unwrap());
        assert!(sock.0.exists());
        let _listener = bind(&sock.0).unwrap();
        UnixStream::connect(&sock.0).await.unwrap();
    }

    #[tokio::test]
    async fn bind_refuses_when_running() {
        let sock = Sock::new("running");
        let tx = start(&sock);
        publish(&tx, "network", &state(Kind::Eth, None));
        assert_eq!(bind(&sock.0).unwrap_err().kind(), io::ErrorKind::AddrInUse);
        assert_eq!(next(&mut connect(&sock).await).await, ETH);
    }
}
