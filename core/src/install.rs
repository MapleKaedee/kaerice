//! `kaericed install-cursor FOLDER NAME`: installs the cursor themes of an unpacked download. A process of its own, not
//! the daemon, so a file that breaks it breaks nothing else. Called by quickshell/scripts/install-cursor.sh.

use std::collections::HashSet;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use crate::cursor::{
    BYTES, Dirs, INDEX, encode, exists, frames, inherits, link, load, siblings, valid,
};
use crate::windows::{self, ROLES};

pub fn run(mut args: impl Iterator<Item = OsString>) -> ExitCode {
    let (Some(folder), Some(label), Ok(dirs)) = (args.next(), args.next(), Dirs::new()) else {
        eprintln!("usage: kaericed install-cursor FOLDER NAME");
        return ExitCode::FAILURE;
    };
    match install(&dirs, Path::new(&folder), &label.to_string_lossy(), WORK) {
        Ok(report) => {
            report.notes.iter().for_each(|note| eprintln!("{note}"));
            report.installed.iter().for_each(|name| println!("{name}"));
            ExitCode::SUCCESS
        }
        Err(reason) => {
            eprintln!("{reason}");
            ExitCode::FAILURE
        }
    }
}

#[derive(Debug, Default)]
struct Report {
    installed: Vec<String>,
    /// Why others were not.
    notes: Vec<String>,
}

/// A folder of the download and its files, without links.
struct Folder {
    path: PathBuf,
    files: Vec<OsString>,
}

/// A theme in the stage.
struct Theme {
    /// The first one that can be used.
    names: Vec<String>,
    inherits: Vec<String>,
}

/// Bytes that one download may read and decode, and its dropped themes write: a small PNG can hold a big picture.
const WORK: u64 = 1 << 30;

/// The error is the reason for the user.
fn install(dirs: &Dirs, root: &Path, label: &str, mut work: u64) -> Result<Report, String> {
    let mut folders = Vec::new();
    walk(root, 8, &mut 5000, &mut folders);
    let [own, ..] = dirs.icons();
    let stage = own.join(format!(".kaerice-install-{}", std::process::id()));
    let mut report = Report::default();
    // for all themes together: one download can hold thousands
    let mut left = dirs.limit;
    for folder in &folders {
        // one that is not installed gives its share back: its stage is removed
        let mut rest = left;
        match add(dirs, root, label, folder, &stage, &mut work, &mut rest) {
            Ok(None) => {}
            Ok(Some(Ok(name))) => {
                left = rest;
                report.installed.push(name);
            }
            Ok(Some(Err(taken))) => report.notes.push(format!("{taken} is already installed.")),
            Err(e) => report.notes.push(e.to_string()),
        }
        // what a dropped one wrote, or they would write without end
        work = work.saturating_sub(left - rest);
        let _ = fs::remove_dir_all(&stage);
    }
    report.notes.dedup();
    if !report.installed.is_empty() {
        return Ok(report);
    }
    Err(if report.notes.is_empty() {
        reason(&folders).into()
    } else {
        report.notes.join("\n")
    })
}

/// Links are not followed: the download may lead anywhere.
fn walk(path: &Path, depth: usize, left: &mut usize, folders: &mut Vec<Folder>) {
    let (mut files, mut inner) = (Vec::new(), Vec::new());
    for entry in fs::read_dir(path).into_iter().flatten().flatten() {
        if *left == 0 {
            break;
        }
        *left -= 1;
        match entry.file_type() {
            Ok(kind) if kind.is_dir() => inner.push(entry.path()),
            Ok(kind) if kind.is_file() => files.push(entry.file_name()),
            _ => {}
        }
    }
    folders.push(Folder {
        path: path.to_owned(),
        files,
    });
    if depth > 0 {
        inner
            .iter()
            .for_each(|path| walk(path, depth - 1, left, folders));
    }
}

/// The name of the new theme, or the name that is taken.
fn add(
    dirs: &Dirs,
    root: &Path,
    label: &str,
    folder: &Folder,
    stage: &Path,
    work: &mut u64,
    left: &mut u64,
) -> io::Result<Option<Result<String, String>>> {
    let theme = match linux(root, folder, stage, work, left)? {
        Some(theme) => theme,
        None => match windows(root, folder, stage, work, left)? {
            Some(theme) => theme,
            None => return Ok(None),
        },
    };
    let names = theme.names.iter().map(String::as_str);
    let name = safe_name(names.chain([label]));
    let icons = dirs.icons();
    if icons.iter().any(|dir| exists(&dir.join(&name))) {
        return Ok(Some(Err(name)));
    }
    let mut index = format!("[Icon Theme]\nName={name}\n");
    if !theme.inherits.is_empty() {
        index += &format!("Inherits={}\n", theme.inherits.join(","));
    }
    fs::write(stage.join("index.theme"), index)?;
    fs::rename(stage, icons[0].join(&name))?;
    Ok(Some(Ok(name)))
}

/// `left`: bytes that may still be written.
fn linux(
    root: &Path,
    folder: &Folder,
    stage: &Path,
    work: &mut u64,
    left: &mut u64,
) -> io::Result<Option<Theme>> {
    let theme = match folder.path.parent() {
        Some(theme) if folder.path != root && folder.path.ends_with("cursors") => theme,
        _ => return Ok(None),
    };
    let cursors = stage.join("cursors");
    let mut given = HashSet::new();
    for name in &folder.files {
        let file = open(&folder.path.join(name), BYTES, work);
        if let Some(file) = file.filter(|file| frames(file).is_some()) {
            *left = spend(*left, &file)?;
            fs::create_dir_all(&cursors)?;
            fs::write(cursors.join(name), file)?;
            given.insert(name.clone());
        }
    }
    if given.is_empty() {
        return Ok(None);
    }
    link(&cursors, siblings(&folder.path).0, &mut given)?;
    let inherits = match theme.join("index.theme").is_symlink() {
        true => Vec::new(),
        false => inherits(theme),
    };
    Ok(Some(Theme {
        names: vec![folder_name(theme, root)],
        inherits: inherits.into_iter().filter(|name| valid(name)).collect(),
    }))
}

fn windows(
    root: &Path,
    folder: &Folder,
    stage: &Path,
    work: &mut u64,
    left: &mut u64,
) -> io::Result<Option<Theme>> {
    let mut files: Vec<_> = folder.files.iter().collect();
    files.sort();
    let text = |name: &OsString| name.to_string_lossy().to_lowercase();
    let ends = |name: &OsString, end: &str| text(name).ends_with(end);
    let path = |name: &OsString| folder.path.join(name);
    let scheme = files
        .iter()
        .filter(|name| ends(name, ".inf"))
        .find_map(|name| windows::scheme(&open(&path(name), INDEX, work)?));
    files.retain(|name| ends(name, ".cur") || ends(name, ".ani"));

    let cursors = stage.join("cursors");
    for (role, (file, links)) in ROLES.iter().enumerate() {
        let named = scheme.as_ref().and_then(|s| s.files[role].as_ref());
        let named = files
            .iter()
            .filter(|name| named.is_some_and(|named| text(name) == named.to_lowercase()));
        let guessed = files
            .iter()
            .filter(|name| windows::guess(&name.to_string_lossy()) == Some(role));
        let found = named
            .chain(guessed)
            .find_map(|name| encode(&windows::read(&open(&path(name), BYTES, work)?, work)?));
        let Some(found) = found else {
            // without an arrow it is no theme
            match role {
                0 => return Ok(None),
                _ => continue,
            }
        };
        *left = spend(*left, &found)?;
        fs::create_dir_all(&cursors)?;
        fs::write(cursors.join(file), found)?;
        for name in *links {
            symlink(file, cursors.join(name))?;
        }
    }
    let mut names = Vec::from_iter(scheme.and_then(|s| s.name));
    let folder = folder_name(&folder.path, root);
    if !["cursor", "cursors"].contains(&folder.to_lowercase().as_str()) {
        names.push(folder);
    }
    Ok(Some(Theme {
        names,
        // for the names that Windows has nothing for
        inherits: vec!["Adwaita".into()],
    }))
}

/// A file of the download, paid from `work`: hard links can make one file many.
fn open(path: &Path, limit: u64, work: &mut u64) -> Option<Vec<u8>> {
    let limit = limit.min(*work);
    let file = load(path, limit);
    // one that is too big was read that far
    *work -= file.as_ref().map_or(limit, |file| file.len() as u64);
    file
}

fn spend(left: u64, file: &[u8]) -> io::Result<u64> {
    let left = left.checked_sub(file.len() as u64);
    left.ok_or_else(|| io::Error::other("The theme is too big."))
}

/// "" for the root, whose name is made up.
fn folder_name(path: &Path, root: &Path) -> String {
    let name = path.file_name().filter(|_| path != root);
    name.unwrap_or_default().to_string_lossy().into_owned()
}

/// The first name that can be the name of a theme, made usable.
fn safe_name<'a>(names: impl IntoIterator<Item = &'a str>) -> String {
    let safe = |name: &str| {
        let plain = |c: char| if c == '/' || c.is_control() { ' ' } else { c };
        let name: String = name.chars().map(plain).collect();
        let name = name.trim().trim_start_matches(['.', ' ']);
        let mut end = name.len().min(100);
        while !name.is_char_boundary(end) {
            end -= 1;
        }
        Some(name[..end].trim_end().to_owned()).filter(|name| valid(name))
    };
    let mut names = names.into_iter();
    names.find_map(safe).unwrap_or_else(|| "Cursor".into())
}

fn reason(folders: &[Folder]) -> &'static str {
    let names = folders.iter().flat_map(|f| &f.files);
    let names: Vec<_> = names.map(|n| n.to_string_lossy().to_lowercase()).collect();
    let any = |ends: &[&str]| {
        names
            .iter()
            .any(|n| ends.iter().any(|end| n.ends_with(end)))
    };
    if names.iter().any(|name| name == "manifest.hl") {
        "This is a Hyprcursor theme, which other apps cannot read."
    } else if any(&[".cursorfx", ".curxptheme", ".cape"]) {
        "This format cannot be converted."
    } else if any(&[".exe", ".msi"]) {
        "This installer cannot be read without running it."
    } else if any(&[".png", ".svg", ".gif"]) {
        "These are images without a click point, not cursors."
    } else {
        "No cursors were found."
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cursor::{Image, THEME, bytes, list};
    use crate::windows::tests::{ani, plain};
    use std::env;

    /// A home, a system folder and an unpacked download, removed at the end.
    struct Home(PathBuf);
    impl Home {
        fn new(name: &str) -> Home {
            let dir =
                env::temp_dir().join(format!("kaericed-{}-install-{name}", std::process::id()));
            let _ = fs::remove_dir_all(&dir);
            fs::create_dir_all(dir.join("in")).unwrap();
            Home(dir)
        }
        fn install(&self) -> Result<Report, String> {
            self.install_within(WORK)
        }
        fn install_within(&self, work: u64) -> Result<Report, String> {
            let dirs = Dirs {
                home: self.0.join("home"),
                system: self.0.join("system"),
                limit: THEME,
            };
            install(&dirs, &self.0.join("in"), "My Download", work)
        }
        fn write(&self, path: &str, data: impl AsRef<[u8]>) -> &Home {
            let path = self.0.join(path);
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            fs::write(path, data).unwrap();
            self
        }
        fn link(&self, target: &str, path: &str) -> &Home {
            let path = self.0.join(path);
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            symlink(target, path).unwrap();
            self
        }
        fn read(&self, path: &str) -> Vec<u8> {
            fs::read(self.0.join(path)).unwrap_or_default()
        }
        fn names(&self, path: &str) -> Vec<String> {
            let names = list(&self.0.join(path)).into_iter();
            let mut names: Vec<_> = names.map(|n| n.into_string().unwrap()).collect();
            names.sort();
            names
        }
    }
    impl Drop for Home {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    const OWN: &str = "home/.local/share/icons";

    fn xcursor(size: u32) -> Vec<u8> {
        let image = Image {
            size,
            width: 2,
            height: 2,
            xhot: 0,
            yhot: 0,
            delay: 0,
            pixels: vec![255; 16],
        };
        encode(&[image]).unwrap()
    }

    #[test]
    fn a_linux_theme_is_copied() {
        let b = Home::new("linux");
        b.write("in/Pack/A/cursors/left_ptr", xcursor(24))
            .write("in/Pack/A/cursors/README", "text")
            .write("in/Pack/A/cursors/broken", &xcursor(24)[..40])
            .write("in/Pack/A/install.sh", "touch /tmp/never")
            .write(
                "in/Pack/A/index.theme",
                "[Icon Theme]\nName=Evil\nInherits=Adwaita,../x,default,/etc\nExec=x\n",
            )
            .link("left_ptr", "in/Pack/A/cursors/arrow")
            .link("arrow", "in/Pack/A/cursors/default")
            .link("broken", "in/Pack/A/cursors/wait");
        let report = b.install().unwrap();
        assert_eq!(report.installed, ["A"]);
        assert_eq!(b.names(OWN), ["A"]);
        assert_eq!(b.names(&format!("{OWN}/A")), ["cursors", "index.theme"]);
        assert_eq!(
            b.names(&format!("{OWN}/A/cursors")),
            ["arrow", "default", "left_ptr"]
        );
        assert_eq!(b.read(&format!("{OWN}/A/cursors/default")), xcursor(24));
        assert!(b.0.join(OWN).join("A/cursors/default").is_symlink());
        assert_eq!(
            b.read(&format!("{OWN}/A/index.theme")),
            b"[Icon Theme]\nName=A\nInherits=Adwaita\n"
        );
    }

    #[test]
    fn a_theme_without_a_folder_has_the_name_of_the_download() {
        let b = Home::new("bare");
        b.write("in/cursors/left_ptr", xcursor(24));
        assert_eq!(b.install().unwrap().installed, ["My Download"]);
        assert_eq!(
            b.read(&format!("{OWN}/My Download/index.theme")),
            b"[Icon Theme]\nName=My Download\n"
        );
    }

    #[test]
    fn links_out_of_the_folder_are_not_followed() {
        let b = Home::new("outside");
        b.write("out/cursors/left_ptr", xcursor(24))
            .write("out/Normal.cur", plain(32, 1))
            .link("../../../out/cursors/left_ptr", "in/A/cursors/left_ptr")
            .link("../../out/cursors", "in/B/cursors")
            .link("../../out/Normal.cur", "in/C/Normal.cur")
            .link("../../out", "in/D")
            .link("/dev/zero", "in/E/cursors/left_ptr");
        assert_eq!(b.install().err().unwrap(), "No cursors were found.");
        assert!(b.names(OWN).is_empty());
    }

    fn inf(files: &[&str]) -> String {
        format!(
            "[R]\nHKCU,\"Control Panel\\Cursors\\Schemes\",\"%N%\",,\"{}\"\n[Strings]\nN=\"Oguri Cap\"\n",
            files.join(",")
        )
    }

    #[test]
    fn windows_cursors_are_converted() {
        let b = Home::new("windows");
        let names: Vec<_> = (0..17).map(|i| format!("{i}.ani")).collect();
        let files: Vec<_> = names.iter().map(String::as_str).collect();
        b.write("in/x/Install.INF", inf(&files));
        for name in &names {
            b.write(
                &format!("in/x/{name}"),
                ani(2, &[], &[plain(48, 1), plain(48, 2)]),
            );
        }
        assert_eq!(b.install().unwrap().installed, ["Oguri Cap"]);
        let cursors = format!("{OWN}/Oguri Cap/cursors");
        for (file, links) in ROLES {
            let data = b.read(&format!("{cursors}/{file}"));
            let frames = frames(&data).unwrap();
            assert_eq!(
                (frames.len(), frames[0].size, frames[0].delay),
                (2, 48, 100)
            );
            for link in links {
                let to = fs::read_link(b.0.join(&cursors).join(link)).unwrap();
                assert_eq!(to, Path::new(file), "{link}");
            }
        }
        assert_eq!(
            b.read(&format!("{OWN}/Oguri Cap/index.theme")),
            b"[Icon Theme]\nName=Oguri Cap\nInherits=Adwaita\n"
        );
    }

    #[test]
    fn the_inf_is_helped_by_file_names() {
        let b = Home::new("helped");
        // Help is missing in the inf, Busy has no file of that name, Wait is broken
        b.write(
            "in/x/a.inf",
            inf(&["MyArrow.ANI", "", "gone.ani", "Broken.ani"]),
        )
        .write("in/x/myarrow.ani", plain(32, 1))
        .write("in/x/Help Select.cur", plain(32, 2))
        .write("in/x/Working.cur", plain(32, 3))
        .write("in/x/Broken.ani", "RIFF")
        .write("in/x/other.cur", plain(32, 3));
        b.install().unwrap();
        let files: Vec<_> = b.names(&format!("{OWN}/Oguri Cap/cursors"));
        let has = |name: &str| files.iter().any(|f| f == name);
        assert!(has("left_ptr") && has("help") && has("progress"));
        assert!(!has("wait") && !has("watch"));
    }

    #[test]
    fn without_an_inf_names_are_enough() {
        let b = Home::new("no-inf");
        b.write("in/Cute Pack/Normal.cur", plain(32, 1))
            .write("in/Cursors/Normal.cur", plain(32, 1));
        let mut installed = b.install().unwrap().installed;
        installed.sort();
        assert_eq!(installed, ["Cute Pack", "My Download"]);
    }

    #[test]
    fn without_an_arrow_it_is_refused() {
        let b = Home::new("no-arrow");
        b.write("in/Busy.cur", plain(32, 1));
        assert_eq!(b.install().err().unwrap(), "No cursors were found.");
        assert!(b.names(OWN).is_empty());
    }

    #[test]
    fn several_themes_are_installed() {
        let b = Home::new("several");
        b.write("in/A/cursors/left_ptr", xcursor(24))
            .write("in/B/cursors/left_ptr", xcursor(48))
            .write("system/B/index.theme", "");
        let report = b.install().unwrap();
        assert_eq!(report.installed, ["A"]);
        assert_eq!(report.notes, ["B is already installed."]);
        assert_eq!(b.names(OWN), ["A"]);
    }

    #[test]
    fn an_installed_theme_is_not_touched() {
        let b = Home::new("again");
        b.write("in/A/cursors/left_ptr", xcursor(24));
        b.install().unwrap();
        b.write("in/A/cursors/left_ptr", xcursor(48));
        assert_eq!(b.install().err().unwrap(), "A is already installed.");
        assert_eq!(b.names(OWN), ["A"]);
        assert_eq!(b.read(&format!("{OWN}/A/cursors/left_ptr")), xcursor(24));
    }

    #[test]
    fn names_are_made_safe() {
        for (name, safe) in [
            ("Oguri Cap", "Oguri Cap"),
            ("../x", "x"),
            ("a/b", "a b"),
            (" .hidden ", "hidden"),
            ("a\nb", "a b"),
            ("", "Fallback"),
            ("..", "Fallback"),
            ("default", "Fallback"),
            ("kaerice-cursor-A-48", "Fallback"),
        ] {
            assert_eq!(safe_name([name, "Fallback"]), safe, "{name:?}");
        }
        let long = "ä".repeat(150);
        let safe = safe_name([long.as_str()]);
        assert!(safe.len() <= 100 && long.starts_with(&safe) && valid(&safe));
        assert!(valid(&safe_name(["", ".."])));
    }

    #[test]
    fn each_refusal_has_its_reason() {
        for (files, reason) in [
            (
                &["A/manifest.hl", "A/hyprcursors/x.hlc"][..],
                "This is a Hyprcursor theme, which other apps cannot read.",
            ),
            (&["a.CursorFX"], "This format cannot be converted."),
            (&["a.CurXPTheme"], "This format cannot be converted."),
            (&["a.cape"], "This format cannot be converted."),
            (
                &["setup.EXE", "a.png"],
                "This installer cannot be read without running it.",
            ),
            (
                &["a.png", "b.svg"],
                "These are images without a click point, not cursors.",
            ),
            (
                &["a.gif"],
                "These are images without a click point, not cursors.",
            ),
            (&["readme.txt"], "No cursors were found."),
            (&[], "No cursors were found."),
        ] {
            let b = Home::new("reason");
            for file in files {
                b.write(&format!("in/{file}"), "x");
            }
            assert_eq!(b.install().err().unwrap(), reason, "{files:?}");
        }
    }

    #[test]
    fn the_walk_is_limited() {
        let b = Home::new("deep");
        let deep = (0..9).map(|i| format!("{i}/")).collect::<String>();
        b.write(&format!("in/{deep}A/cursors/left_ptr"), xcursor(24));
        assert!(b.install().is_err());
        let b = Home::new("many");
        for i in 0..5001 {
            b.write(&format!("in/{i}"), "");
        }
        let mut left = 5000;
        let mut folders = Vec::new();
        walk(&b.0.join("in"), 8, &mut left, &mut folders);
        assert_eq!((left, folders[0].files.len()), (0, 5000));
    }

    #[test]
    fn a_theme_has_a_limit() {
        let b = Home::new("limit");
        b.write("in/A/cursors/left_ptr", xcursor(24))
            .write("in/B/Normal.cur", plain(32, 1));
        let dirs = Dirs {
            home: b.0.join("home"),
            system: b.0.join("system"),
            limit: 50,
        };
        let result = install(&dirs, &b.0.join("in"), "x", WORK);
        assert_eq!(result.err().unwrap(), "The theme is too big.");
        assert!(b.names(OWN).is_empty());
    }

    #[test]
    fn decoding_has_a_budget_for_the_whole_download() {
        let b = Home::new("work");
        let file = plain(32, 1);
        b.write("in/A/Normal.cur", &file)
            .write("in/B/Normal.cur", &file);
        // the file, its picture, the pixels
        let one = (2 * file.len() + bytes(32, 32)) as u64;
        b.install_within(one + one / 2).unwrap();
        assert_eq!(b.names(OWN).len(), 1);
    }

    #[test]
    fn reading_takes_from_the_budget() {
        // hard links can make one file many
        let b = Home::new("read");
        let file = xcursor(24);
        b.write("in/A/cursors/left_ptr", &file);
        assert!(b.install_within(file.len() as u64 - 1).is_err());
        assert!(b.install_within(file.len() as u64).is_ok());
        let b = Home::new("read-again");
        b.write("in/A/cursors/left_ptr", &file)
            .write("in/B/cursors/left_ptr", &file);
        let n = file.len() as u64;
        b.install_within(n + n / 2).unwrap();
        assert_eq!(b.names(OWN).len(), 1);
        // one that is too big was read up to the limit
        let mut work = 15;
        assert!(open(&b.0.join("in/A/cursors/left_ptr"), 5, &mut work).is_none());
        assert_eq!(work, 10);
    }

    #[test]
    fn all_themes_share_one_limit() {
        let b = Home::new("limit-all");
        let file = xcursor(24);
        b.write("in/A/cursors/left_ptr", &file)
            .write("in/B/cursors/left_ptr", &file);
        let dirs = Dirs {
            home: b.0.join("home"),
            system: b.0.join("system"),
            limit: file.len() as u64 * 3 / 2,
        };
        let report = install(&dirs, &b.0.join("in"), "x", WORK).unwrap();
        assert_eq!(b.names(OWN).len(), 1);
        assert_eq!(report.notes, ["The theme is too big."]);
    }

    #[test]
    fn a_theme_that_is_not_installed_gives_its_share_back() {
        let b = Home::new("give-back");
        // the download itself is a theme, so it comes first
        b.write("in/Normal.cur", plain(32, 1))
            .write("system/x/index.theme", "")
            .write("in/B/cursors/left_ptr", xcursor(24));
        let dirs = Dirs {
            home: b.0.join("home"),
            system: b.0.join("system"),
            // Normal.cur as an XCursor
            limit: (64 + bytes(32, 32)) as u64,
        };
        let report = install(&dirs, &b.0.join("in"), "x", WORK).unwrap();
        assert_eq!(report.installed, ["B"]);
        assert_eq!(report.notes, ["x is already installed."]);
    }

    #[test]
    fn a_dropped_theme_pays_for_what_it_wrote() {
        // or the themes that are dropped would write without end
        let b = Home::new("dropped");
        let arrow = plain(32, 1);
        b.write("in/Normal.cur", &arrow)
            .write("system/My Download/index.theme", "")
            .write("in/B/cursors/left_ptr", xcursor(24));
        // what both read and decode, then the XCursor of the first
        let read = 2 * arrow.len() - 22 + bytes(32, 32) + xcursor(24).len();
        let need = (read + 64 + bytes(32, 32)) as u64;
        assert!(b.install_within(need - 1).is_err());
        assert_eq!(b.install_within(need).unwrap().installed, ["B"]);
    }

    #[test]
    fn nothing_is_left_behind() {
        let b = Home::new("left");
        b.write("in/A/cursors/left_ptr", xcursor(24))
            .write("in/B/Busy.cur", plain(32, 1));
        b.install().unwrap();
        assert_eq!(b.names(OWN), ["A"]);
        // a file where the folder should be
        let b = Home::new("blocked");
        b.write("in/A/cursors/left_ptr", xcursor(24))
            .write("home/.local/share/icons", "");
        assert!(b.install().is_err());
        assert_eq!(b.read("home/.local/share/icons"), b"");
    }
}
