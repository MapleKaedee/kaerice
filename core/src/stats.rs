use std::fs;

use rustix::fs::statvfs;
use serde::Serialize;
use serde_json::Value;

use crate::server::Answer;

#[derive(Serialize)]
struct Stats {
    cpu: Cpu,
    mem: Mem,
    disk: Disk,
    /// Seconds.
    uptime: u64,
}

/// Ticks since boot.
#[derive(Debug, PartialEq, Serialize)]
struct Cpu {
    idle: u64,
    total: u64,
}

/// Bytes.
#[derive(Debug, PartialEq, Serialize)]
struct Mem {
    total: u64,
    available: u64,
}

/// Bytes. used + available is less than total: some blocks are kept for root.
#[derive(Serialize)]
struct Disk {
    total: u64,
    used: u64,
    available: u64,
}

/// The "stats.read" call.
pub fn read() -> Answer<Value> {
    let stats = stats().ok_or("Failed")?;
    Ok(serde_json::to_value(stats).expect("stats are plain data"))
}

fn stats() -> Option<Stats> {
    let text = |file| fs::read_to_string(file).ok();
    Some(Stats {
        cpu: cpu(&text("/proc/stat")?)?,
        mem: mem(&text("/proc/meminfo")?)?,
        disk: disk()?,
        uptime: uptime(&text("/proc/uptime")?)?,
    })
}

fn cpu(stat: &str) -> Option<Cpu> {
    let all = stat.lines().next()?.strip_prefix("cpu ")?;
    let ticks: Vec<u64> = all
        .split_whitespace()
        .map(|n| n.parse().ok())
        .collect::<Option<_>>()?;
    Some(Cpu {
        // idle + iowait
        idle: ticks.get(3)? + ticks.get(4)?,
        total: ticks.iter().sum(),
    })
}

fn mem(meminfo: &str) -> Option<Mem> {
    let bytes = |name| {
        let rest = meminfo.lines().find_map(|line| line.strip_prefix(name))?;
        let kib: u64 = rest.split_whitespace().next()?.parse().ok()?;
        Some(kib * 1024)
    };
    Some(Mem {
        total: bytes("MemTotal:")?,
        available: bytes("MemAvailable:")?,
    })
}

fn disk() -> Option<Disk> {
    let root = statvfs("/").ok()?;
    Some(Disk {
        total: root.f_blocks * root.f_frsize,
        used: (root.f_blocks - root.f_bfree) * root.f_frsize,
        available: root.f_bavail * root.f_frsize,
    })
}

fn uptime(text: &str) -> Option<u64> {
    text.split('.').next()?.parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    const STAT: &str = "cpu  100 2 30 400 50 6 7 8 9 10\ncpu0 1 2 3 4 5 6 7 8 9 10\nintr 5\n";
    const MEMINFO: &str =
        "MemTotal:       16000000 kB\nMemFree:         1000 kB\nMemAvailable:    4000000 kB\n";

    #[test]
    fn cpu_counts_every_column_and_waiting_is_idle() {
        let wanted = Cpu {
            idle: 450,
            total: 622,
        };
        assert_eq!(cpu(STAT), Some(wanted));
    }

    #[test]
    fn mem_in_bytes() {
        let wanted = Mem {
            total: 16_384_000_000,
            available: 4_096_000_000,
        };
        assert_eq!(mem(MEMINFO), Some(wanted));
    }

    #[test]
    fn uptime_in_whole_seconds() {
        assert_eq!(uptime("22345.99 80000.00\n"), Some(22345));
        assert_eq!(uptime("0.50 0.10\n"), Some(0));
    }

    #[test]
    fn unusable_text() {
        for text in ["", "\n", "cpu", "cpu 1 2 3", "cpu a b c d e", "x 1 2 3 4 5"] {
            assert_eq!(cpu(text), None, "{text:?}");
        }
        for text in [
            "",
            "MemTotal: 5 kB\n",
            "MemTotal: x kB\nMemAvailable: 5 kB\n",
        ] {
            assert_eq!(mem(text), None, "{text:?}");
        }
        for text in ["", "x", "-5.0 1"] {
            assert_eq!(uptime(text), None, "{text:?}");
        }
    }

    #[test]
    fn reads_this_machine() {
        let now = read().unwrap();
        let n = |part: &str, key: &str| now[part][key].as_u64().unwrap();
        assert!(n("cpu", "idle") < n("cpu", "total"));
        assert!(n("mem", "available") < n("mem", "total"));
        let disk = n("disk", "used") + n("disk", "available");
        assert!(n("disk", "used") > 0 && disk <= n("disk", "total"));
        assert!(now["uptime"].as_u64().unwrap() > 0);
    }
}
