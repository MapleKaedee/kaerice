mod follow;
mod network;
mod server;
mod wifi;

use std::env;
use std::error::Error;
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

use tokio::sync::watch;

use server::{Call, Topics};
use wifi::Wifi;

#[tokio::main(flavor = "current_thread")]
async fn main() -> ExitCode {
    let error = match run().await {
        Err(e) => e,
        Ok(()) => "stopped".into(),
    };
    eprintln!("kaericed: {error}");
    ExitCode::FAILURE
}

/// Any part that ends takes the daemon down: systemd starts it again.
async fn run() -> Result<(), Box<dyn Error>> {
    let listener = server::bind(&directory()?.join("kaericed.sock"))?;
    let bus = zbus::Connection::system().await?;
    let (tx, rx) = watch::channel(Topics::new());
    let wifi = Wifi::new(bus.clone(), Duration::from_secs(60));
    let calls = move |call: Call| {
        let wifi = wifi.clone();
        async move {
            match call.name.split_once('.') {
                Some(("wifi", what)) => wifi.call(what, &call.args).await,
                _ => Err("UnknownCall".into()),
            }
        }
    };
    let limit = Duration::from_secs(5);
    tokio::select! {
        r = server::serve(listener, rx, calls) => r?,
        r = network::watch(&bus, &tx, limit) => r?,
        r = wifi::watch(&bus, &tx, limit) => r?,
    }
    Ok(())
}

// RUNTIME_DIRECTORY is set by systemd
fn directory() -> Result<PathBuf, Box<dyn Error>> {
    if let Some(dir) = env::var_os("RUNTIME_DIRECTORY") {
        return Ok(dir.into());
    }
    let base = env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is not set")?;
    let dir = PathBuf::from(base).join("kaerice");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}
