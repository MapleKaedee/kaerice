use std::collections::BTreeMap;
use std::io;
use std::os::unix::net::UnixStream as Probe;
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{mpsc, watch};

/// The longest line a client may send.
const LINE: usize = 4096;

/// The last state of every topic, as the line that is sent (without the newline).
pub type Topics = BTreeMap<&'static str, String>;

#[derive(Deserialize)]
struct Request {
    id: u64,
    call: String,
    #[serde(default)]
    args: Value,
}

pub struct Call {
    pub name: String,
    pub args: Value,
}

/// The error is a code: the text for it is made in QML.
pub type Answer<T = ()> = Result<T, String>;

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

pub async fn serve<H, F>(
    listener: UnixListener,
    rx: watch::Receiver<Topics>,
    handler: H,
) -> io::Result<()>
where
    H: Fn(Call) -> F + Clone + Send + 'static,
    F: Future<Output = Answer<Value>> + Send + 'static,
{
    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(client(stream, rx.clone(), handler.clone()));
    }
}

/// Ends when the client leaves.
async fn client<H, F>(
    mut stream: UnixStream,
    mut rx: watch::Receiver<Topics>,
    handler: H,
) -> io::Result<()>
where
    H: Fn(Call) -> F,
    F: Future<Output = Answer<Value>> + Send + 'static,
{
    let mut sent = Topics::new();
    let mut input = Vec::with_capacity(LINE);
    let (done, mut answers) = mpsc::unbounded_channel();
    loop {
        let topics = rx.borrow_and_update().clone();
        for (topic, line) in &topics {
            if sent.get(topic) != Some(line) {
                stream.write_all(format!("{line}\n").as_bytes()).await?;
            }
        }
        sent = topics;
        tokio::select! {
            // in this order: the state that a call changed goes out before its answer
            biased;
            changed = rx.changed() => if changed.is_err() { return Ok(()) },
            Some(line) = answers.recv() => stream.write_all(format!("{line}\n").as_bytes()).await?,
            read = stream.read_buf(&mut input) => if read? == 0 { return Ok(()) },
        }
        while let Some(end) = input.iter().position(|b| *b == b'\n') {
            let line: Vec<u8> = input.drain(..=end).collect();
            let Ok(Request { id, call, args }) = serde_json::from_slice(&line) else {
                // never the line itself: it can hold a password
                eprintln!("kaericed: a client sent a line that is not a call");
                continue;
            };
            let (done, answer) = (done.clone(), handler(Call { name: call, args }));
            // a task of its own: a call goes on after its client left
            tokio::spawn(async move { done.send(reply(id, answer.await)) });
        }
        if input.len() > LINE {
            return Ok(());
        }
    }
}

fn reply(id: u64, answer: Answer<Value>) -> String {
    match answer {
        Ok(Value::Null) => format!(r#"{{"id":{id},"ok":true}}"#),
        Ok(data) => format!(r#"{{"id":{id},"ok":true,"data":{data}}}"#),
        Err(code) => format!(r#"{{"id":{id},"error":{}}}"#, Value::from(code)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::network::{Kind, Status};
    use std::path::PathBuf;
    use std::time::Duration;
    use tokio::io::{AsyncBufReadExt, BufReader, Lines};
    use tokio::time::{sleep, timeout};

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

    /// "ok" succeeds, "slow" too but later, "data" gives its args back, any other name is the error.
    async fn handler(call: Call) -> Answer<Value> {
        match call.name.as_str() {
            "ok" => Ok(Value::Null),
            "slow" => {
                sleep(Duration::from_millis(200)).await;
                Ok(Value::Null)
            }
            "data" => Ok(call.args),
            "echo" => Err(call.args["text"].as_str().unwrap_or("none").to_owned()),
            other => Err(other.to_owned()),
        }
    }

    fn start(sock: &Sock) -> watch::Sender<Topics> {
        let (tx, rx) = watch::channel(Topics::new());
        tokio::spawn(serve(bind(&sock.0).unwrap(), rx, handler));
        tx
    }

    async fn send(lines: &mut Lines<BufReader<UnixStream>>, text: &[u8]) {
        lines.get_mut().get_mut().write_all(text).await.unwrap();
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

    const OK: &str = r#"{"id":7,"ok":true}"#;
    const FAILED: &str = r#"{"id":7,"error":"Failed"}"#;

    #[tokio::test]
    async fn answers_the_caller_only() {
        let sock = Sock::new("caller");
        let tx = start(&sock);
        let (mut a, mut b) = (connect(&sock).await, connect(&sock).await);
        send(&mut a, b"{\"id\":7,\"call\":\"ok\",\"args\":{}}\n").await;
        assert_eq!(next(&mut a).await, OK);
        publish(&tx, "network", &state(Kind::Eth, None));
        assert_eq!(next(&mut b).await, ETH);
    }

    #[tokio::test]
    async fn answers_errors() {
        let sock = Sock::new("errors");
        let _tx = start(&sock);
        let mut a = connect(&sock).await;
        send(&mut a, b"{\"id\":7,\"call\":\"Failed\"}\n").await;
        assert_eq!(next(&mut a).await, FAILED);
    }

    #[tokio::test]
    async fn answers_with_data() {
        let sock = Sock::new("data");
        let _tx = start(&sock);
        let mut a = connect(&sock).await;
        send(
            &mut a,
            b"{\"id\":7,\"call\":\"data\",\"args\":{\"downloads\":true,\"packages\":false}}\n",
        )
        .await;
        assert_eq!(
            next(&mut a).await,
            r#"{"id":7,"ok":true,"data":{"downloads":true,"packages":false}}"#
        );
    }

    #[tokio::test]
    async fn state_before_its_answer() {
        let sock = Sock::new("order");
        let (tx, rx) = watch::channel(Topics::new());
        tokio::spawn(serve(bind(&sock.0).unwrap(), rx, move |call: Call| {
            let tx = tx.clone();
            async move {
                publish(&tx, "network", &call.args);
                Ok(Value::Null)
            }
        }));
        let mut a = connect(&sock).await;
        // many times: an unordered select! picks one of the two at random
        for i in 0..50 {
            let line = format!("{{\"id\":7,\"call\":\"ok\",\"args\":{i}}}\n");
            send(&mut a, line.as_bytes()).await;
            assert_eq!(next(&mut a).await, format!(r#"{{"network":{i}}}"#));
            assert_eq!(next(&mut a).await, OK);
        }
    }

    #[tokio::test]
    async fn an_error_is_escaped() {
        let sock = Sock::new("escaped");
        let _tx = start(&sock);
        let mut a = connect(&sock).await;
        send(
            &mut a,
            b"{\"id\":1,\"call\":\"echo\",\"args\":{\"text\":\"a\\\"b\\n\"}}\n",
        )
        .await;
        assert_eq!(next(&mut a).await, r#"{"id":1,"error":"a\"b\n"}"#);
    }

    #[tokio::test]
    async fn bad_lines_are_skipped() {
        let sock = Sock::new("bad");
        let _tx = start(&sock);
        let mut a = connect(&sock).await;
        for line in [
            &b"\n"[..],
            b"{\n",
            b"5\n",
            b"[]\n",
            b"\xff\xfe\n",
            b"{\"call\":\"ok\"}\n",
            b"{\"id\":\"x\",\"call\":\"ok\"}\n",
            b"{\"id\":-1,\"call\":\"ok\"}\n",
            b"{\"id\":7,\"call\":\"ok\"}\n",
        ] {
            send(&mut a, line).await;
        }
        assert_eq!(next(&mut a).await, OK);
    }

    #[tokio::test]
    async fn call_split_over_two_writes() {
        let sock = Sock::new("split");
        let tx = start(&sock);
        let mut a = connect(&sock).await;
        send(&mut a, b"{\"id\":7,\"ca").await;
        publish(&tx, "network", &state(Kind::Eth, None));
        assert_eq!(next(&mut a).await, ETH);
        send(&mut a, b"ll\":\"ok\"}\n").await;
        assert_eq!(next(&mut a).await, OK);
    }

    #[tokio::test]
    async fn two_calls_in_one_write() {
        let sock = Sock::new("two");
        let _tx = start(&sock);
        let mut a = connect(&sock).await;
        send(
            &mut a,
            b"{\"id\":1,\"call\":\"slow\"}\n{\"id\":7,\"call\":\"ok\"}\n",
        )
        .await;
        assert_eq!(next(&mut a).await, OK);
        assert_eq!(next(&mut a).await, r#"{"id":1,"ok":true}"#);
    }

    #[tokio::test]
    async fn long_line_ends_the_client() {
        let sock = Sock::new("long");
        let _tx = start(&sock);
        let (mut a, mut b) = (connect(&sock).await, connect(&sock).await);
        // the daemon may hang up while this is still being written
        let _ = a.get_mut().get_mut().write_all(&[b'x'; 20_000]).await;
        // a hang-up with unread input is a reset, not an end
        let end = timeout(Duration::from_secs(2), a.next_line()).await;
        assert!(matches!(end, Ok(Ok(None) | Err(_))), "{end:?}");
        send(&mut b, b"{\"id\":7,\"call\":\"ok\"}\n").await;
        assert_eq!(next(&mut b).await, OK);
    }

    #[tokio::test]
    async fn slow_call_does_not_block_topics() {
        let sock = Sock::new("slow");
        let tx = start(&sock);
        let mut a = connect(&sock).await;
        send(&mut a, b"{\"id\":7,\"call\":\"slow\"}\n").await;
        sleep(Duration::from_millis(20)).await;
        publish(&tx, "network", &state(Kind::Eth, None));
        assert_eq!(next(&mut a).await, ETH);
        assert_eq!(next(&mut a).await, OK);
    }

    #[tokio::test]
    async fn call_finishes_after_the_client_left() {
        let sock = Sock::new("left");
        let (_tx, rx) = watch::channel(Topics::new());
        let (done, mut finished) = tokio::sync::mpsc::unbounded_channel();
        tokio::spawn(serve(bind(&sock.0).unwrap(), rx, move |_| {
            let done = done.clone();
            async move {
                done.send("started").unwrap();
                sleep(Duration::from_millis(100)).await;
                done.send("finished").unwrap();
                Ok(Value::Null)
            }
        }));
        let mut a = connect(&sock).await;
        send(&mut a, b"{\"id\":7,\"call\":\"ok\"}\n").await;
        let limit = Duration::from_secs(2);
        assert_eq!(timeout(limit, finished.recv()).await, Ok(Some("started")));
        drop(a);
        assert_eq!(timeout(limit, finished.recv()).await, Ok(Some("finished")));
    }
}
