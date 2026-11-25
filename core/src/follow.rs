use std::future::poll_fn;
use std::pin::Pin;
use std::task::Poll;
use std::time::Duration;

use serde::Serialize;
use tokio::sync::Notify;
use tokio::time;
use zbus::export::futures_core::Stream;
use zbus::message::Type::Signal;
use zbus::proxy::MethodFlags;
use zbus::wire::DynamicDeserialize;
use zbus::{Connection, DynamicType, MatchRule, MessageStream, Proxy};

/// One change sends several signals.
const JOIN: Duration = Duration::from_millis(200);

/// Reads at start, after every signal of `rules`, and when the service `name` comes or goes.
/// Shows None when it cannot be read. Ends only when the bus connection is lost.
pub async fn follow<T, F: Future<Output = zbus::Result<T>>>(
    conn: &Connection,
    name: &'static str,
    rules: Vec<MatchRule<'static>>,
    timeout: Duration,
    read: impl Fn() -> F,
    show: impl Fn(Option<T>),
) -> zbus::Result<()> {
    let owner = MatchRule::builder()
        .msg_type(Signal)
        .sender("org.freedesktop.DBus")
        .interface("org.freedesktop.DBus")
        .member("NameOwnerChanged")
        .arg(0, name)
        .build()?;
    let mut streams = Vec::new();
    for rule in rules.into_iter().chain([owner]) {
        streams.push(MessageStream::for_match_rule(rule, conn, None).await?);
    }

    let dirty = Notify::new();
    // apart from the reads: a stream that nobody polls stalls the connection, the reply to a read included
    let pump = async {
        while next(&mut streams).await {
            dirty.notify_one();
        }
    };
    let reads = async {
        let mut failed = false;
        loop {
            let answer = time::timeout(timeout, read())
                .await
                .unwrap_or_else(|_| Err(zbus::Error::Failure("no answer".into())));
            let retry = answer.as_ref().is_err_and(|e| !gone(e));
            if let Err(e) = &answer
                && !failed
            {
                eprintln!("kaericed: {name}: {e}");
            }
            failed = answer.is_err();
            show(answer.ok());
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

/// False when a stream has ended.
async fn next(streams: &mut [MessageStream]) -> bool {
    poll_fn(|cx| {
        for stream in &mut *streams {
            if let Poll::Ready(message) = Pin::new(stream).poll_next(cx) {
                return Poll::Ready(message.is_some());
            }
        }
        Poll::Pending
    })
    .await
}

/// Not on the bus. Its return is a signal, so there is nothing to retry.
pub fn gone(error: &zbus::Error) -> bool {
    use zbus::fdo::Error::{NameHasNoOwner, ServiceUnknown};
    matches!(error, zbus::Error::FDO(e) if matches!(**e, NameHasNoOwner(_) | ServiceUnknown(_)))
}

// NoAutoStart: a service that the user stopped stays stopped
pub async fn call<B, R>(
    conn: &Connection,
    name: &str,
    path: &str,
    interface: &str,
    method: &str,
    body: &B,
) -> zbus::Result<R>
where
    B: Serialize + DynamicType,
    R: for<'d> DynamicDeserialize<'d>,
{
    Proxy::new(conn, name, path, interface)
        .await?
        .call_with_flags(method, MethodFlags::NO_AUTO_START, body)
        .await?
        .ok_or(zbus::Error::InvalidReply)
}
