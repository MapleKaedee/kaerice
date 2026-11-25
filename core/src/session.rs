use std::path::Path;
use std::{env, fs, io};

use serde_json::{Value, json};

use crate::server::Answer;

const MANAGERS: [&str; 3] = ["pacman", "paru", "yay"];
const DOWNLOADERS: [&str; 4] = ["curl", "wget", "aria2c", "yt-dlp"];

/// The "session.check" call: what a logout or power off would interrupt.
pub fn check() -> Answer<Value> {
    let home = env::var_os("HOME").ok_or("Failed")?;
    look(
        Path::new("/proc"),
        Path::new("/var/lib/pacman/db.lck"),
        &Path::new(&home).join("Downloads"),
    )
}

/// Fails when it cannot look: that must not pass for "nothing".
fn look(proc: &Path, lock: &Path, downloads: &Path) -> Answer<Value> {
    let (packages, downloads) = found(proc, lock, downloads).map_err(|_| "Failed")?;
    Ok(json!({"packages": packages, "downloads": downloads}))
}

fn found(proc: &Path, lock: &Path, downloads: &Path) -> io::Result<(bool, bool)> {
    let mut packages = lock.try_exists()?;
    let mut downloading = unfinished(downloads)?;
    for entry in fs::read_dir(proc)? {
        // no such file: not a process, or one that just ended
        let Ok(comm) = fs::read_to_string(entry?.path().join("comm")) else {
            continue;
        };
        packages |= MANAGERS.contains(&comm.trim_end());
        downloading |= DOWNLOADERS.contains(&comm.trim_end());
    }
    Ok((packages, downloading))
}

fn unfinished(folder: &Path) -> io::Result<bool> {
    let entries = match fs::read_dir(folder) {
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(false),
        entries => entries?,
    };
    for entry in entries {
        let name = entry?.file_name();
        let name = name.as_encoded_bytes();
        let partial = name.ends_with(b".part") || name.ends_with(b".crdownload");
        if partial && !name.starts_with(b".") {
            return Ok(true);
        }
    }
    Ok(false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    /// A root with proc/ and downloads/, removed at the end.
    struct Root(PathBuf);
    impl Root {
        fn new(name: &str) -> Root {
            let dir =
                std::env::temp_dir().join(format!("kaericed-{}-root-{name}", std::process::id()));
            let _ = fs::remove_dir_all(&dir);
            fs::create_dir_all(dir.join("proc/self")).unwrap();
            fs::create_dir(dir.join("downloads")).unwrap();
            Root(dir).process("1", "systemd")
        }
        fn process(self, pid: &str, comm: &str) -> Root {
            let dir = self.0.join("proc").join(pid);
            fs::create_dir(&dir).unwrap();
            fs::write(dir.join("comm"), format!("{comm}\n")).unwrap();
            self
        }
        fn file(self, path: &str) -> Root {
            fs::write(self.0.join(path), "").unwrap();
            self
        }
        fn check(&self) -> Answer<Value> {
            let at = |name| self.0.join(name);
            look(&at("proc"), &at("db.lck"), &at("downloads"))
        }
    }
    impl Drop for Root {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn found(packages: bool, downloads: bool) -> Answer<Value> {
        Ok(json!({"packages": packages, "downloads": downloads}))
    }

    #[test]
    fn nothing_runs() {
        assert_eq!(Root::new("nothing").check(), found(false, false));
    }

    #[test]
    fn package_managers() {
        for name in ["pacman", "paru", "yay"] {
            let root = Root::new(name).process("200", name);
            assert_eq!(root.check(), found(true, false), "{name}");
        }
    }

    #[test]
    fn pacman_lock() {
        let root = Root::new("lock").file("db.lck");
        assert_eq!(root.check(), found(true, false));
    }

    #[test]
    fn download_programs() {
        for name in ["curl", "wget", "aria2c", "yt-dlp"] {
            let root = Root::new(name).process("200", name);
            assert_eq!(root.check(), found(false, true), "{name}");
        }
    }

    #[test]
    fn unfinished_files() {
        for name in ["x.part", "a b.crdownload"] {
            let root = Root::new(name).file(&format!("downloads/{name}"));
            assert_eq!(root.check(), found(false, true), "{name}");
        }
        for name in ["x.parts", "part", ".x.part", "x.zip"] {
            let root = Root::new(name).file(&format!("downloads/{name}"));
            assert_eq!(root.check(), found(false, false), "{name}");
        }
    }

    #[test]
    fn other_names_do_not_match() {
        let root = Root::new("other")
            .process("200", "pacman-key")
            .process("201", "curlew");
        assert_eq!(root.check(), found(false, false));
    }

    #[test]
    fn a_process_that_just_ended_is_skipped() {
        let root = Root::new("ended").process("200", "pacman");
        fs::create_dir(root.0.join("proc/100")).unwrap();
        assert_eq!(root.check(), found(true, false));
    }

    #[test]
    fn no_downloads_folder_is_fine() {
        let root = Root::new("folder");
        fs::remove_dir(root.0.join("downloads")).unwrap();
        assert_eq!(root.check(), found(false, false));
    }

    #[test]
    fn what_cannot_be_read_fails() {
        let failed: Answer<Value> = Err("Failed".into());
        let root = Root::new("proc");
        fs::remove_dir_all(root.0.join("proc")).unwrap();
        assert_eq!(root.check(), failed);
        let root = Root::new("file");
        fs::remove_dir(root.0.join("downloads")).unwrap();
        assert_eq!(root.file("downloads").check(), failed);
    }
}
