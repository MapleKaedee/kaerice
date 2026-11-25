use std::collections::{BTreeSet, HashSet};
use std::env;
use std::ffi::OsString;
use std::fs;
use std::io::{self, Read};
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use serde::Serialize;
use serde_json::Value;
use tokio::task;

use crate::server::Answer;

/// A copy of a theme in one size: "kaerice-cursor-<theme>-<size>". It becomes the theme "default", so that every app
/// shows that size, whatever it asks for.
/// shortcut: one size, so outputs scaled above 1 show it smaller; add a second size when one is used
const PREFIX: &str = "kaerice-cursor-";
/// Files that name a theme themselves, and the line that makes them follow "default".
const NAMED: [(&str, &str, &str); 4] = [
    (
        ".config/gtk-3.0/settings.ini",
        "gtk-cursor-theme-name",
        "gtk-cursor-theme-name=default\n",
    ),
    (
        ".config/gtk-4.0/settings.ini",
        "gtk-cursor-theme-name",
        "gtk-cursor-theme-name=default\n",
    ),
    (
        ".gtkrc-2.0",
        "gtk-cursor-theme-name",
        "gtk-cursor-theme-name=\"default\"\n",
    ),
    (".Xresources", "Xcursor.theme", "Xcursor.theme: default\n"),
];
/// The type of an image in a cursor file.
const IMAGE: u32 = 0xfffd_0002;
/// The longest side of an image, in pixels.
pub const SIDE: u32 = 1024;
/// The most bytes a cursor file may have, before and after.
pub const BYTES: u64 = 64 << 20;
/// The most images of a cursor file.
const IMAGES: usize = 4096;
/// The most bytes that are read and written for one copy.
pub const THEME: u64 = 256 << 20;
/// The most bytes of an index.theme.
pub const INDEX: u64 = 1 << 20;
/// The most themes whose cursors a theme may use.
const THEMES: usize = 32;

#[derive(Serialize)]
struct State {
    themes: BTreeSet<String>,
    /// "" when unknown.
    theme: String,
    size: u32,
}

/// The "cursor.read" call.
pub fn read() -> Answer<Value> {
    let state = Dirs::new()?.state();
    Ok(serde_json::to_value(state).expect("the state is plain data"))
}

/// The "cursor.set" call: gives the name of the copy. Not on the main thread, a big theme takes a while.
pub async fn set(args: Value) -> Answer<Value> {
    let work = move || Dirs::new()?.set(&args).map(Value::from);
    task::spawn_blocking(work).await.map_err(|_| "Failed")?
}

pub struct Dirs {
    pub home: PathBuf,
    pub system: PathBuf,
    /// Bytes, for each copy.
    pub limit: u64,
}

impl Dirs {
    pub fn new() -> Answer<Dirs> {
        Ok(Dirs {
            home: env::var_os("HOME").ok_or("Failed")?.into(),
            system: "/usr/share/icons".into(),
            limit: THEME,
        })
    }

    /// In the order in which libXcursor searches them. Old versions skip the first, Flatpak shows only that one.
    pub fn icons(&self) -> [PathBuf; 3] {
        [
            self.home.join(".local/share/icons"),
            self.home.join(".icons"),
            self.system.clone(),
        ]
    }

    fn state(&self) -> State {
        let mut themes = BTreeSet::new();
        for dir in self.icons() {
            let names = list(&dir).into_iter().filter_map(|n| n.into_string().ok());
            themes.extend(names.filter(|n| valid(n) && dir.join(n).join("cursors").is_dir()));
        }
        let (theme, size) = self.current();
        State {
            themes,
            theme,
            size,
        }
    }

    fn current(&self) -> (String, u32) {
        let [own, ..] = self.icons();
        let copy = copy(&own.join("default")).and_then(|name| {
            let (theme, size) = name.strip_prefix(PREFIX)?.rsplit_once('-')?;
            Some((theme.to_owned(), size.parse().ok()?))
        });
        copy.unwrap_or_else(|| {
            let inherited = |dir: &PathBuf| inherits(&dir.join("default")).into_iter().next();
            let theme = self.icons().iter().find_map(inherited).unwrap_or_default();
            let size = self.size(&theme).unwrap_or(24);
            (theme, size)
        })
    }

    /// The size of a theme that has no copy: apps ask for 24 and get the closest.
    fn size(&self, theme: &str) -> Option<u32> {
        let folders = self.folders(theme);
        let mut files = folders.iter().map(|dir| dir.join("left_ptr"));
        let file = files.find_map(|path| load(&path, BYTES))?;
        let sizes = frames(&file)?.into_iter().map(|f| f.size);
        sizes.min_by_key(|s| s.abs_diff(24))
    }

    /// The cursors of a theme and of the themes it inherits from, nearest first.
    fn folders(&self, theme: &str) -> Vec<PathBuf> {
        let mut names = vec![theme.to_owned()];
        let mut folders = Vec::new();
        let mut i = 0;
        while let Some(name) = names.get(i).cloned() {
            i += 1;
            for dir in self.icons().map(|dir| dir.join(&name)) {
                for next in inherits(&dir) {
                    if valid(&next) && names.len() < THEMES && !names.contains(&next) {
                        names.push(next);
                    }
                }
                let cursors = dir.join("cursors");
                if cursors.is_dir() {
                    folders.push(cursors);
                }
            }
        }
        folders
    }

    fn set(&self, args: &Value) -> Answer<String> {
        let theme = args["theme"].as_str().filter(|t| valid(t));
        let theme = theme.ok_or("InvalidArgs")?;
        let size = args["size"].as_u64().filter(|s| (16..=96).contains(s));
        let size = size.ok_or("InvalidArgs")? as u32;
        let exists = |dir: &PathBuf| dir.join(theme).join("cursors").is_dir();
        if !self.icons().iter().any(exists) {
            return Err("NoTheme".into());
        }
        static ONE: Mutex<()> = Mutex::new(());
        let _one = ONE.lock();
        self.apply(theme, size).map_err(|e| {
            eprintln!("kaericed: the cursor was not changed: {e}");
            "Failed".into()
        })
    }

    fn apply(&self, theme: &str, size: u32) -> io::Result<String> {
        let [own, old, _] = self.icons();
        for dir in [&own, &old] {
            let (default, backup) = (dir.join("default"), dir.join("default.pre-kaerice"));
            if exists(&default) && copy(&default).is_none() && exists(&backup) {
                let message = format!("{} already exists, move it away first", backup.display());
                return Err(io::Error::other(message));
            }
        }

        let name = format!("{PREFIX}{theme}-{size}");
        let target = own.join(&name);
        // "default" may lead to a copy with the same name: that one stays whole until this one is
        let fresh = own.join(".kaerice-cursor-new");
        let _ = fs::remove_dir_all(&fresh);
        let built = self.build(theme, size, &fresh);
        if built.is_err() {
            let _ = fs::remove_dir_all(&fresh);
        }
        built?;
        let _ = fs::remove_dir_all(&target);
        fs::rename(&fresh, &target)?;

        // in this order: ~/.icons may be a link to the other folder, and the relative link must win there
        point(&old, &target)?;
        point(&own, Path::new(&name))?;
        self.name_default();
        for other in list(&own) {
            if other.as_encoded_bytes().starts_with(PREFIX.as_bytes()) && other != *name {
                let _ = fs::remove_dir_all(own.join(other));
            }
        }
        Ok(name)
    }

    fn build(&self, theme: &str, size: u32, dir: &Path) -> io::Result<()> {
        let cursors = dir.join("cursors");
        fs::create_dir_all(&cursors)?;
        let (mut left, mut made) = (self.limit, false);
        for folder in self.folders(theme) {
            let (links, files) = siblings(&folder);
            let mut given = HashSet::new();
            let mut add = |name: OsString, given: &mut HashSet<OsString>| -> io::Result<()> {
                let to = cursors.join(&name);
                if exists(&to) {
                    return Ok(());
                }
                let Some(file) = load(&folder.join(&name), BYTES) else {
                    return Ok(());
                };
                let copy = convert(&file, size);
                let used = file.len() + copy.as_ref().map_or(0, Vec::len);
                left = left
                    .checked_sub(used as u64)
                    .ok_or_else(|| io::Error::other("the theme is too big"))?;
                if let Some(copy) = copy {
                    fs::write(to, copy)?;
                    made = true;
                    given.insert(name);
                }
                Ok(())
            };
            for name in files {
                add(name, &mut given)?;
            }
            // to a name that a nearer theme has: as a link it would show that cursor
            for (name, _) in link(&cursors, links, &mut given)? {
                add(name, &mut given)?;
            }
        }
        if !made {
            return Err(io::Error::other("no usable cursor in the theme"));
        }
        // never "Inherits": "default" leads here, and a circle hangs apps
        fs::write(
            dir.join("index.theme"),
            format!("[Icon Theme]\nName={PREFIX}{theme}-{size}\n"),
        )
    }

    fn name_default(&self) {
        for (file, key, line) in NAMED {
            let path = self.home.join(file);
            let Ok(old) = fs::read_to_string(&path) else {
                continue;
            };
            let names = |l: &str| l.split(['=', ':']).next().map(str::trim) == Some(key);
            let new: String = old
                .split_inclusive('\n')
                .map(|l| if names(l) { line } else { l })
                .collect();
            if new != old
                && let Err(e) = fs::write(&path, new)
            {
                eprintln!("kaericed: {file} keeps its cursor theme: {e}");
            }
        }
    }
}

pub fn exists(path: &Path) -> bool {
    path.symlink_metadata().is_ok()
}

pub fn list(dir: &Path) -> Vec<OsString> {
    let entries = fs::read_dir(dir).into_iter().flatten().flatten();
    entries.map(|entry| entry.file_name()).collect()
}

/// The names in a folder: links to another name in it, with that name, and the others.
pub fn siblings(dir: &Path) -> (Vec<(OsString, OsString)>, Vec<OsString>) {
    let (mut links, mut others) = (Vec::new(), Vec::new());
    for name in list(dir) {
        match fs::read_link(dir.join(&name)) {
            Ok(to) if to.file_name() == Some(to.as_os_str()) => links.push((name, to.into())),
            _ => others.push(name),
        }
    }
    (links, others)
}

/// Most names are links to a few files, or to such a link. Makes those that lead to a given name and gives the others back.
pub fn link(
    dir: &Path,
    mut links: Vec<(OsString, OsString)>,
    given: &mut HashSet<OsString>,
) -> io::Result<Vec<(OsString, OsString)>> {
    loop {
        let (ready, rest): (Vec<_>, Vec<_>) =
            links.into_iter().partition(|(_, to)| given.contains(to));
        if ready.is_empty() {
            return Ok(rest);
        }
        links = rest;
        for (name, target) in ready {
            if !exists(&dir.join(&name)) {
                symlink(target, dir.join(&name))?;
                given.insert(name);
            }
        }
    }
}

/// Themes are folder names, and come from the socket and from index.theme files.
pub fn valid(theme: &str) -> bool {
    !theme.is_empty()
        && theme.len() <= 200
        && !theme.starts_with('.')
        && !theme.contains(|c: char| c == '/' || c.is_control())
        && theme != "default"
        && !theme.starts_with(PREFIX)
}

/// The name of the copy that a link leads to.
fn copy(link: &Path) -> Option<String> {
    let target = fs::read_link(link).ok()?;
    let name = target.file_name()?.to_str()?;
    name.starts_with(PREFIX).then(|| name.to_owned())
}

pub fn inherits(theme: &Path) -> Vec<String> {
    let text = load(&theme.join("index.theme"), INDEX).unwrap_or_default();
    let text = String::from_utf8_lossy(&text);
    let mut lines = text.lines().filter_map(|line| line.split_once('='));
    let value = lines.find(|(key, _)| key.trim() == "Inherits");
    let names = value.map_or("", |(_, names)| names).split([',', ';']);
    let names = names.map(|name| name.trim_matches(|c: char| c == '"' || c.is_whitespace()));
    names.filter(|n| !n.is_empty()).map(str::to_owned).collect()
}

pub fn load(path: &Path, limit: u64) -> Option<Vec<u8>> {
    if !path.is_file() {
        return None;
    }
    // not metadata().len(): files in /proc say 0 and may never end
    let mut data = Vec::new();
    let file = fs::File::open(path).ok()?;
    file.take(limit + 1).read_to_end(&mut data).ok()?;
    (data.len() as u64 <= limit).then_some(data)
}

/// Makes "default" in this folder a link to the target. One that is not ours is moved away, like install.sh does.
fn point(dir: &Path, target: &Path) -> io::Result<()> {
    fs::create_dir_all(dir)?;
    let (default, fresh) = (dir.join("default"), dir.join(".kaerice-cursor-default"));
    if exists(&default) && copy(&default).is_none() {
        fs::rename(&default, dir.join("default.pre-kaerice"))?;
    }
    let _ = fs::remove_file(&fresh);
    symlink(target, &fresh)?;
    fs::rename(fresh, default)
}

/// One image of a cursor file. Several of one size are an animation.
pub struct Image {
    pub size: u32,
    pub width: u32,
    pub height: u32,
    pub xhot: u32,
    pub yhot: u32,
    /// Milliseconds.
    pub delay: u32,
    /// Premultiplied ARGB, little endian.
    pub pixels: Vec<u8>,
}

/// The same, as it is in a file.
pub struct Frame<'a> {
    pub size: u32,
    pub width: u32,
    pub height: u32,
    pub xhot: u32,
    pub yhot: u32,
    pub delay: u32,
    pub pixels: &'a [u8],
}

/// Cursor files come from anywhere and a panic ends the daemon: nothing here may index or overflow.
pub fn frames(file: &[u8]) -> Option<Vec<Frame<'_>>> {
    let word = |at: usize| {
        Some(u32::from_le_bytes(
            file.get(at..)?.get(..4)?.try_into().ok()?,
        ))
    };
    if file.get(..4)? != b"Xcur" {
        return None;
    }
    let toc = word(4)? as usize;
    let mut frames = Vec::new();
    let mut total = 0;
    for i in 0..word(12)? as usize {
        let entry = toc + 12 * i;
        if word(entry)? != IMAGE {
            continue;
        }
        let at = word(entry + 8)? as usize;
        let field = |n: usize| word(at + 4 * n);
        let (size, width, height) = (field(2)?, field(4)?, field(5)?);
        if size == 0 || !(1..=SIDE).contains(&width) || !(1..=SIDE).contains(&height) {
            return None;
        }
        // many entries may lead to one image
        total += bytes(width, height);
        if total as u64 > BYTES || frames.len() == IMAGES {
            return None;
        }
        frames.push(Frame {
            size,
            width,
            height,
            xhot: field(6)?,
            yhot: field(7)?,
            delay: field(8)?,
            pixels: file.get(at + 36..)?.get(..bytes(width, height))?,
        });
    }
    (!frames.is_empty()).then_some(frames)
}

/// The same cursor with its images in this size only.
fn convert(file: &[u8], size: u32) -> Option<Vec<u8>> {
    let frames = frames(file)?;
    let sizes = || frames.iter().map(|f| f.size);
    let source = sizes().filter(|s| *s >= size).min().or(sizes().max())?;
    let scaled = |n: u32| {
        let (n, size, source) = (u64::from(n), u64::from(size), u64::from(source));
        (n * size + source / 2) / source
    };
    let side = |n: u32| u32::try_from(scaled(n).max(1)).ok().filter(|n| *n <= SIDE);
    let images: Vec<_> = frames
        .iter()
        .filter(|f| f.size == source)
        .map(|f| Some((f, side(f.width)?, side(f.height)?)))
        .collect::<Option<_>>()?;
    // before the work
    let total: usize = images.iter().map(|(_, w, h)| bytes(*w, *h)).sum();
    if total as u64 > BYTES {
        return None;
    }
    let images: Vec<_> = images
        .into_iter()
        .map(|(frame, width, height)| {
            let hot = |n: u32, side: u32| scaled(n).min(u64::from(side) - 1) as u32;
            let from = (frame.width as usize, frame.height as usize);
            Image {
                size,
                width,
                height,
                xhot: hot(frame.xhot, width),
                yhot: hot(frame.yhot, height),
                delay: frame.delay,
                pixels: resize(frame.pixels, from, (width as usize, height as usize)),
            }
        })
        .collect();
    encode(&images)
}

pub fn bytes(width: u32, height: u32) -> usize {
    4 * width as usize * height as usize
}

/// A cursor file. None if it would be empty or too big, or an image has not the pixels of its sides.
pub fn encode(images: &[Image]) -> Option<Vec<u8>> {
    let fits = |i: &Image| {
        i.size > 0
            && (1..=SIDE).contains(&i.width)
            && (1..=SIDE).contains(&i.height)
            && i.pixels.len() == bytes(i.width, i.height)
    };
    let total: usize = images.iter().map(|i| 48 + i.pixels.len()).sum();
    if images.is_empty()
        || images.len() > IMAGES
        || total as u64 > BYTES
        || !images.iter().all(fits)
    {
        return None;
    }
    let mut out = b"Xcur".to_vec();
    let put = |out: &mut Vec<u8>, words: &[u32]| {
        out.extend(words.iter().flat_map(|w| w.to_le_bytes()));
    };
    put(&mut out, &[16, 0x1_0000, images.len() as u32]);
    let mut at = 16 + 12 * images.len();
    for i in images {
        put(&mut out, &[IMAGE, i.size, at as u32]);
        at += 36 + i.pixels.len();
    }
    for i in images {
        let (xhot, yhot) = (i.xhot.min(i.width - 1), i.yhot.min(i.height - 1));
        put(
            &mut out,
            &[36, IMAGE, i.size, 1, i.width, i.height, xhot, yhot, i.delay],
        );
        out.extend(&i.pixels);
    }
    Some(out)
}

/// What each target pixel takes from the source: bilinear when it grows, an average when it shrinks.
fn weights(from: usize, to: usize) -> Vec<Vec<(usize, f32)>> {
    let step = from as f32 / to as f32;
    let reach = step.max(1.0);
    (0..to)
        .map(|i| {
            let center = (i as f32 + 0.5) * step - 0.5;
            let first = (center - reach).ceil().max(0.0) as usize;
            let last = ((center + reach).floor() as usize).min(from - 1);
            let all: Vec<_> = (first..=last)
                .map(|s| (s, (1.0 - (s as f32 - center).abs() / reach).max(0.0)))
                .collect();
            let sum: f32 = all.iter().map(|(_, w)| w).sum();
            all.into_iter().map(|(s, w)| (s, w / sum)).collect()
        })
        .collect()
}

/// `pixels` has 4 bytes for each pixel of `from`.
fn resize(pixels: &[u8], from: (usize, usize), to: (usize, usize)) -> Vec<u8> {
    let (columns, rows) = (weights(from.0, to.0), weights(from.1, to.1));
    // the old rows, each in the new width
    let mut wide = Vec::with_capacity(4 * to.0 * from.1);
    for row in pixels.chunks_exact(4 * from.0) {
        for column in &columns {
            for channel in 0..4 {
                let parts = column
                    .iter()
                    .map(|(x, w)| f32::from(row[4 * x + channel]) * w);
                wide.push(parts.sum::<f32>());
            }
        }
    }
    let mut out = Vec::with_capacity(4 * to.0 * to.1);
    for row in &rows {
        for i in 0..4 * to.0 {
            let parts = row.iter().map(|(y, w)| wide[4 * to.0 * y + i] * w);
            out.push(parts.sum::<f32>().round() as u8);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    type Color = [u8; 4];
    const RED: Color = [0, 0, 255, 255];
    const GREEN: Color = [0, 255, 0, 255];
    const BLUE: Color = [255, 0, 0, 255];

    fn put(out: &mut Vec<u8>, words: &[u32]) {
        out.extend(words.iter().flat_map(|w| w.to_le_bytes()));
    }

    /// A cursor file with one plain square per (size, side, hotspot, delay, color).
    fn file(images: &[(u32, u32, u32, u32, Color)]) -> Vec<u8> {
        let mut out = b"Xcur".to_vec();
        put(&mut out, &[16, 0x1_0000, images.len() as u32]);
        let mut at = 16 + 12 * images.len() as u32;
        for (size, side, ..) in images {
            put(&mut out, &[0xfffd_0002, *size, at]);
            at += 36 + 4 * side * side;
        }
        for (size, side, hot, delay, color) in images {
            let words = [36, 0xfffd_0002, *size, 1, *side, *side, *hot, *hot, *delay];
            put(&mut out, &words);
            out.extend(color.repeat((side * side) as usize));
        }
        out
    }

    fn plain(frame: &Frame, color: Color) -> bool {
        frame.pixels.chunks(4).all(|pixel| pixel == color)
    }

    #[test]
    fn a_copy_has_one_size_and_keeps_the_animation() {
        let theme = file(&[(32, 32, 8, 40, RED), (32, 32, 8, 50, BLUE)]);
        let copy = convert(&theme, 48).unwrap();
        let frames = frames(&copy).unwrap();
        let facts = |f: &Frame| (f.size, f.width, f.height, f.xhot, f.yhot, f.delay);
        let facts: Vec<_> = frames.iter().map(facts).collect();
        assert_eq!(facts, [(48, 48, 48, 12, 12, 40), (48, 48, 48, 12, 12, 50)]);
        assert!(plain(&frames[0], RED));
        assert!(plain(&frames[1], BLUE));
    }

    #[test]
    fn the_smallest_size_that_is_big_enough_is_the_source() {
        let theme = file(&[
            (24, 24, 3, 0, RED),
            (36, 36, 4, 0, BLUE),
            (72, 72, 9, 0, GREEN),
        ]);
        for (size, color) in [
            (16, RED),
            (24, RED),
            (32, BLUE),
            (36, BLUE),
            (64, GREEN),
            (96, GREEN),
        ] {
            let copy = convert(&theme, size).unwrap();
            let frames = frames(&copy).unwrap();
            assert_eq!(frames.len(), 1, "{size}");
            assert_eq!(frames[0].width, size);
            assert!(plain(&frames[0], color), "{size}");
        }
    }

    #[test]
    fn the_image_may_be_bigger_than_its_size() {
        let copy = convert(&file(&[(24, 32, 4, 0, RED)]), 48).unwrap();
        let frames = frames(&copy).unwrap();
        assert_eq!(
            (frames[0].size, frames[0].width, frames[0].xhot),
            (48, 64, 8)
        );
    }

    #[test]
    fn the_hotspot_stays_inside() {
        let copy = convert(&file(&[(32, 32, u32::MAX, 0, RED)]), 48).unwrap();
        assert_eq!(frames(&copy).unwrap()[0].xhot, 47);
    }

    #[test]
    fn growing_blends_and_shrinking_averages() {
        let gray = |values: &[u8]| values.iter().flat_map(|v| [*v; 4]).collect::<Vec<u8>>();
        let (two, four) = (gray(&[0, 255]), gray(&[0, 0, 255, 255]));
        for (grown, shrunk) in [
            (resize(&two, (2, 1), (4, 1)), resize(&four, (4, 1), (2, 1))),
            (resize(&two, (1, 2), (1, 4)), resize(&four, (1, 4), (1, 2))),
        ] {
            assert_eq!(grown, gray(&[0, 64, 191, 255]));
            assert_eq!(shrunk, gray(&[36, 219]));
        }
    }

    #[test]
    fn broken_files_are_none() {
        let good = file(&[(32, 32, 8, 0, RED)]);
        assert!(convert(&good, 48).is_some());
        for n in 0..good.len() {
            assert!(convert(&good[..n], 48).is_none(), "{n} bytes");
        }
        assert!(convert(b"[Icon Theme]\nName=Not a cursor\n", 48).is_none());
        // count, position, type, size, width, height
        for (at, value) in [
            (12, 0),
            (12, u32::MAX),
            (24, u32::MAX),
            (16, 1),
            (36, 0),
            (36, 1),
            (44, 0),
            (44, 100_000),
            (48, u32::MAX),
        ] {
            let mut bad = good.clone();
            bad[at..at + 4].copy_from_slice(&u32::to_le_bytes(value));
            assert!(convert(&bad, 48).is_none(), "{value} at {at}");
        }
        let mut bad = good.clone();
        bad[44..52].fill(0xff);
        assert!(convert(&bad, 48).is_none(), "both sides");
    }

    #[test]
    fn encode_is_read_back_by_frames() {
        let pixels: Vec<u8> = (0..4 * 3 * 2).collect();
        let image = |size, delay| Image {
            size,
            width: 3,
            height: 2,
            xhot: 2,
            yhot: 1,
            delay,
            pixels: pixels.clone(),
        };
        let file = encode(&[image(24, 40), image(48, 50)]).unwrap();
        let frames = frames(&file).unwrap();
        let facts = |f: &Frame| (f.size, f.width, f.height, f.xhot, f.yhot, f.delay);
        let facts: Vec<_> = frames.iter().map(facts).collect();
        assert_eq!(facts, [(24, 3, 2, 2, 1, 40), (48, 3, 2, 2, 1, 50)]);
        assert!(frames.iter().all(|f| f.pixels == pixels));
        // not square: width and height must not change places
        let grown = convert(&file, 96).unwrap();
        let grown = self::frames(&grown).unwrap();
        assert_eq!((grown[0].width, grown[0].height), (6, 4));
        let rows: Vec<_> = grown[0].pixels.chunks(24).collect();
        assert_eq!(rows[0][..4], pixels[..4]);
        assert_eq!(rows[3][20..], pixels[20..]);
        assert_eq!(rows[0][20..], pixels[8..12]);
    }

    #[test]
    fn encode_refuses_nothing_and_wrong_sizes() {
        assert!(encode(&[]).is_none());
        for (size, width, height, bytes) in [
            (24, 2, 2, 15),
            (24, 2, 2, 17),
            (24, 0, 2, 0),
            (0, 2, 2, 16),
            (24, 1025, 1, 4100),
        ] {
            let image = Image {
                size,
                width,
                height,
                xhot: 0,
                yhot: 0,
                delay: 0,
                pixels: vec![0; bytes],
            };
            assert!(
                encode(&[image]).is_none(),
                "{size} {width} {height} {bytes}"
            );
        }
    }

    /// One image that many entries of the file lead to.
    fn shared(side: u32, entries: u32) -> Vec<u8> {
        let one = file(&[(side, side, 0, 0, RED)]);
        let mut many = b"Xcur".to_vec();
        put(&mut many, &[16, 0x1_0000, entries]);
        for _ in 0..entries {
            put(&mut many, &[0xfffd_0002, side, 16 + 12 * entries]);
        }
        many.extend(&one[28..]);
        many
    }

    #[test]
    fn one_big_image_is_not_used_many_times() {
        assert!(frames(&shared(1024, 16)).is_some());
        assert!(frames(&shared(1024, 17)).is_none());
    }

    #[test]
    fn too_many_images_are_refused() {
        assert!(frames(&shared(1, 4096)).is_some());
        assert!(frames(&shared(1, 4097)).is_none());
    }

    #[test]
    fn a_theme_has_a_limit() {
        let home = Home::new("theme-limit");
        home.theme("system/A").theme("system/B");
        for i in 0..4 {
            home.write(
                &format!("system/B/cursors/{i}"),
                file(&[(32, 32, 0, 0, RED)]),
            );
        }
        home.set("A", 32).unwrap();
        let mut dirs = home.dirs();
        // each cursor is about 4 kB, read and written
        dirs.limit = 30_000;
        let set = |theme: &str| dirs.set(&json!({ "theme": theme, "size": 32 }));
        assert_eq!(set("B"), Err("Failed".into()));
        assert_eq!(home.names(OWN), ["default", "kaerice-cursor-A-32"]);
        assert!(set("A").is_ok());
    }

    #[test]
    fn the_inherited_themes_have_a_limit() {
        let home = Home::new("inherit-limit");
        let names: Vec<_> = (0..1000).map(|i| format!("T{i}")).collect();
        home.theme("system/A").write(
            "system/A/index.theme",
            format!("Inherits={}\n", names.join(",")),
        );
        for (theme, shape) in [("T5", "wait"), ("T500", "help")] {
            let blue = file(&[(32, 32, 8, 0, BLUE)]);
            home.write(&format!("system/{theme}/cursors/{shape}"), blue);
        }
        home.set("A", 32).unwrap();
        assert_eq!(
            home.names(&format!("{OWN}/kaerice-cursor-A-32/cursors")),
            ["left_ptr", "wait"]
        );
    }

    #[test]
    fn links_to_links_stay_links() {
        let home = Home::new("chains");
        home.theme("system/A");
        // in both orders, one of them is not the order in which the folder is read
        for i in 0..6 {
            let next = |i: usize| {
                if i == 5 {
                    "left_ptr".into()
                } else {
                    format!("up{}", i + 1)
                }
            };
            home.link(&next(i), &format!("system/A/cursors/up{i}"));
        }
        for i in (0..6).rev() {
            let next = |i: usize| {
                if i == 5 {
                    "left_ptr".into()
                } else {
                    format!("down{}", i + 1)
                }
            };
            home.link(&next(i), &format!("system/A/cursors/down{i}"));
        }
        home.set("A", 48).unwrap();
        let cursors = home.0.join(OWN).join("kaerice-cursor-A-48/cursors");
        let files = list(&cursors)
            .into_iter()
            .filter(|n| !cursors.join(n).is_symlink());
        assert_eq!(files.collect::<Vec<_>>(), ["left_ptr"]);
        assert_eq!(list(&cursors).len(), 13);
    }

    #[test]
    fn a_small_file_does_not_become_a_huge_one() {
        let many = shared(32, 3000);
        assert_eq!(frames(&many).unwrap().len(), 3000);
        assert!(convert(&many, 96).is_none());
    }

    /// A home and a system folder with made-up themes, removed at the end.
    struct Home(PathBuf);
    impl Home {
        fn new(name: &str) -> Home {
            let dir =
                env::temp_dir().join(format!("kaericed-{}-cursor-{name}", std::process::id()));
            let _ = fs::remove_dir_all(&dir);
            fs::create_dir(&dir).unwrap();
            Home(dir)
        }
        fn dirs(&self) -> Dirs {
            Dirs {
                home: self.0.join("home"),
                system: self.0.join("system"),
                limit: THEME,
            }
        }
        fn set(&self, theme: &str, size: u32) -> Answer<String> {
            self.dirs().set(&json!({ "theme": theme, "size": size }))
        }
        fn write(&self, path: &str, data: impl AsRef<[u8]>) -> &Home {
            let path = self.0.join(path);
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            fs::write(path, data).unwrap();
            self
        }
        /// A theme with one 32 px cursor.
        fn theme(&self, path: &str) -> &Home {
            let left_ptr = file(&[(32, 32, 8, 0, RED)]);
            self.write(&format!("{path}/cursors/left_ptr"), left_ptr)
        }
        fn link(&self, target: &str, path: &str) -> &Home {
            let path = self.0.join(path);
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            symlink(target, path).unwrap();
            self
        }
        fn read(&self, path: &str) -> String {
            fs::read_to_string(self.0.join(path)).unwrap()
        }
        fn exists(&self, path: &str) -> bool {
            self.0.join(path).symlink_metadata().is_ok()
        }
        /// Where a path leads to, below this folder.
        fn real(&self, path: &str) -> PathBuf {
            let base = self.0.canonicalize().unwrap();
            let real = self.0.join(path).canonicalize().unwrap();
            real.strip_prefix(base).unwrap().to_owned()
        }
        fn names(&self, path: &str) -> Vec<String> {
            let mut names: Vec<_> = list(&self.0.join(path))
                .into_iter()
                .map(|n| n.into_string().unwrap())
                .collect();
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

    #[test]
    fn themes_are_listed_once() {
        let home = Home::new("list");
        home.theme("home/.icons/A")
            .theme(&format!("{OWN}/A"))
            .theme("system/B")
            .theme("system/default")
            .theme(&format!("{OWN}/kaerice-cursor-A-48"))
            .write("system/hicolor/index.theme", "");
        let themes = home.dirs().state().themes;
        assert_eq!(themes.into_iter().collect::<Vec<_>>(), ["A", "B"]);
    }

    #[test]
    fn set_makes_a_copy_and_makes_it_the_default() {
        let home = Home::new("set");
        home.theme("system/A")
            .link("left_ptr", "system/A/cursors/arrow")
            .link("../../B/cursors/left_ptr", "system/A/cursors/hand1")
            .theme("system/B");
        assert_eq!(home.set("A", 48).unwrap(), "kaerice-cursor-A-48");

        let copy = format!("{OWN}/kaerice-cursor-A-48");
        let cursors = home.0.join(&copy).join("cursors");
        for shape in ["left_ptr", "hand1"] {
            let file = fs::read(cursors.join(shape)).unwrap();
            assert_eq!(frames(&file).unwrap()[0].size, 48, "{shape}");
        }
        assert!(!cursors.join("hand1").is_symlink());
        assert_eq!(
            fs::read_link(cursors.join("arrow")).unwrap(),
            Path::new("left_ptr")
        );

        assert_eq!(home.real("home/.icons/default"), Path::new(&copy));
        // relative: Flatpak shows this folder in another place
        assert_eq!(
            fs::read_link(home.0.join(OWN).join("default")).unwrap(),
            Path::new("kaerice-cursor-A-48")
        );
        let state = home.dirs().state();
        assert_eq!((state.theme.as_str(), state.size), ("A", 48));
    }

    #[test]
    fn a_new_copy_replaces_the_old_one_and_nothing_else() {
        let home = Home::new("replace");
        home.theme(&format!("{OWN}/A"))
            .theme(&format!("{OWN}/Bibata-24"))
            .write(&format!("{OWN}/kaerice/keep"), "");
        home.set("A", 48).unwrap();
        home.set("Bibata-24", 64).unwrap();
        assert_eq!(
            home.names(OWN),
            [
                "A",
                "Bibata-24",
                "default",
                "kaerice",
                "kaerice-cursor-Bibata-24-64"
            ]
        );
        assert_eq!(home.names("home/.icons"), ["default"]);
        assert!(home.exists(&format!("{OWN}/A/cursors/left_ptr")));
        let state = home.dirs().state();
        assert_eq!((state.theme.as_str(), state.size), ("Bibata-24", 64));
    }

    #[test]
    fn missing_shapes_come_from_the_inherited_themes() {
        let home = Home::new("inherit");
        home.theme("system/A")
            .write(
                "system/A/index.theme",
                "[Icon Theme]\nInherits=default, ../x,\"B\"\n",
            )
            .write("system/B/index.theme", "[Icon Theme]\nInherits=A\n")
            .write("system/B/cursors/left_ptr", file(&[(32, 32, 8, 0, BLUE)]))
            .write("system/B/cursors/wait", file(&[(32, 32, 8, 0, BLUE)]));
        home.set("A", 32).unwrap();
        let shape = |name: &str| {
            let path = format!("{OWN}/kaerice-cursor-A-32/cursors/{name}");
            fs::read(home.0.join(path)).unwrap()
        };
        assert!(plain(&frames(&shape("left_ptr")).unwrap()[0], RED));
        assert!(plain(&frames(&shape("wait")).unwrap()[0], BLUE));
        let index = home.read(&format!("{OWN}/kaerice-cursor-A-32/index.theme"));
        assert!(!index.contains("Inherits"));

        // "default" is the last copy by now, not a theme of its own
        home.theme("system/C")
            .write("system/C/index.theme", "Inherits=default\n");
        home.set("C", 32).unwrap();
        assert_eq!(
            home.names(&format!("{OWN}/kaerice-cursor-C-32/cursors")),
            ["left_ptr"]
        );
    }

    #[test]
    fn links_lead_to_a_cursor_of_their_own_theme() {
        let home = Home::new("links");
        home.theme("system/A")
            .write("system/A/index.theme", "Inherits=B\n")
            .write("system/A/cursors/bad", "not a cursor")
            .link("missing", "system/A/cursors/wait")
            .link("bad", "system/A/cursors/hand1")
            .link("arrow", "system/A/cursors/crosshair")
            .write("system/A/cursors/cross", file(&[(32, 32, 8, 0, RED)]))
            .link("crosshair", "system/B/cursors/cross")
            .link("cross", "system/B/cursors/tcross")
            .link("left_ptr", "system/B/cursors/hand2")
            .link("crosshair", "system/B/cursors/arrow");
        for shape in ["left_ptr", "wait", "hand1", "crosshair"] {
            let blue = file(&[(32, 32, 8, 0, BLUE)]);
            home.write(&format!("system/B/cursors/{shape}"), blue);
        }
        home.set("A", 32).unwrap();
        let color = |shape: &str, color: Color| {
            let path = format!("{OWN}/kaerice-cursor-A-32/cursors/{shape}");
            let file = fs::read(home.0.join(path)).unwrap_or_default();
            frames(&file).is_some_and(|frames| plain(&frames[0], color))
        };
        assert!(color("left_ptr", RED));
        for shape in ["wait", "hand1", "crosshair", "arrow", "hand2", "tcross"] {
            assert!(color(shape, BLUE), "{shape}");
        }
    }

    #[test]
    fn files_have_a_limit_even_without_a_length() {
        let home = Home::new("limit");
        home.write("ten", "0123456789");
        let ten = home.0.join("ten");
        assert_eq!(load(&ten, 10).unwrap(), b"0123456789");
        assert!(load(&ten, 9).is_none());
        // a regular file of length 0 that is not empty
        assert!(load(Path::new("/proc/self/status"), 9).is_none());
        assert!(load(Path::new("/dev/zero"), 9).is_none());
    }

    #[test]
    fn an_old_default_is_moved_away() {
        let home = Home::new("backup");
        let old = "[Icon Theme]\nInherits=A\n";
        home.theme("system/A")
            .write("home/.icons/default/index.theme", old);
        home.set("A", 48).unwrap();
        home.set("A", 64).unwrap();
        assert_eq!(
            home.names("home/.icons"),
            ["default", "default.pre-kaerice"]
        );
        assert_eq!(
            home.read("home/.icons/default.pre-kaerice/index.theme"),
            old
        );
    }

    #[test]
    fn a_taken_backup_name_changes_nothing() {
        let home = Home::new("taken");
        let settings = "gtk-cursor-theme-name=A\n";
        home.theme("system/A")
            .write("home/.config/gtk-3.0/settings.ini", settings)
            .write("home/.icons/default/index.theme", "new")
            .write(&format!("{OWN}/default/index.theme"), "other")
            .write(&format!("{OWN}/default.pre-kaerice/index.theme"), "old");
        assert_eq!(home.set("A", 48), Err("Failed".into()));
        assert_eq!(home.names("home/.icons"), ["default"]);
        assert_eq!(home.read("home/.icons/default/index.theme"), "new");
        assert_eq!(home.read(&format!("{OWN}/default/index.theme")), "other");
        assert_eq!(home.read("home/.config/gtk-3.0/settings.ini"), settings);
    }

    #[test]
    fn icons_may_be_a_link_to_the_other_folder() {
        let home = Home::new("linked");
        home.theme(&format!("{OWN}/A"))
            .link(".local/share/icons", "home/.icons");
        home.set("A", 48).unwrap();
        assert_eq!(
            fs::read_link(home.0.join(OWN).join("default")).unwrap(),
            Path::new("kaerice-cursor-A-48")
        );
    }

    #[test]
    fn state_before_the_first_set() {
        let home = Home::new("state");
        let state = |home: &Home| {
            let state = home.dirs().state();
            (state.theme, state.size)
        };
        assert_eq!(state(&home), (String::new(), 24));
        home.write("system/default/index.theme", "[Icon Theme]\nInherits=B\n");
        assert_eq!(state(&home), ("B".into(), 24));
        home.theme("system/A")
            .write("home/.icons/default/index.theme", "Inherits = A,B\n");
        assert_eq!(state(&home), ("A".into(), 32));
    }

    #[test]
    fn config_files_name_default() {
        let home = Home::new("config");
        let gtk = |name: &str| {
            format!("[Settings]\n{name}\ngtk-cursor-theme-size=24\n# gtk-cursor-theme-name=x\n")
        };
        home.theme("system/A")
            .write(
                "home/.config/gtk-3.0/settings.ini",
                gtk("gtk-cursor-theme-name=A"),
            )
            .write(
                "home/.config/gtk-4.0/settings.ini",
                gtk("gtk-cursor-theme-name = A"),
            )
            .write("home/.gtkrc-2.0", "gtk-cursor-theme-name=\"A\"\n")
            .write(
                "home/.Xresources",
                "Xcursor.theme_core: 1\nXcursor.theme: A",
            );
        home.set("A", 48).unwrap();
        let named = gtk("gtk-cursor-theme-name=default");
        assert_eq!(home.read("home/.config/gtk-3.0/settings.ini"), named);
        assert_eq!(home.read("home/.config/gtk-4.0/settings.ini"), named);
        assert_eq!(
            home.read("home/.gtkrc-2.0"),
            "gtk-cursor-theme-name=\"default\"\n"
        );
        assert_eq!(
            home.read("home/.Xresources"),
            "Xcursor.theme_core: 1\nXcursor.theme: default\n"
        );
    }

    #[test]
    fn config_files_are_not_made() {
        let home = Home::new("no-config");
        home.theme("system/A")
            .write("home/.config/gtk-3.0/settings.ini", "[Settings]\n");
        home.set("A", 48).unwrap();
        assert_eq!(home.names("home/.config"), ["gtk-3.0"]);
        assert_eq!(home.names("home"), [".config", ".icons", ".local"]);
        assert_eq!(
            home.read("home/.config/gtk-3.0/settings.ini"),
            "[Settings]\n"
        );
    }

    #[test]
    fn bad_arguments_are_refused() {
        let home = Home::new("arguments");
        home.theme("system/A");
        let long = "A".repeat(201);
        for theme in [
            "",
            "../x",
            "a/b",
            ".x",
            "default",
            "kaerice-cursor-A-48",
            "a\nb",
            &long,
        ] {
            assert_eq!(home.set(theme, 48), Err("InvalidArgs".into()), "{theme:?}");
        }
        for size in [json!(15), json!(97), json!(-1), json!(48.5), json!("48")] {
            let args = json!({ "theme": "A", "size": size });
            assert_eq!(home.dirs().set(&args), Err("InvalidArgs".into()), "{size}");
        }
        assert_eq!(home.dirs().set(&json!({})), Err("InvalidArgs".into()));
        assert_eq!(home.set("C", 48), Err("NoTheme".into()));
        assert!(!home.exists("home"));
    }

    #[test]
    fn an_unusable_theme_changes_nothing() {
        let home = Home::new("unusable");
        home.theme("system/A")
            .write("system/Text/cursors/left_ptr", "not a cursor")
            .link("/dev/zero", "system/Text/cursors/wait");
        home.set("A", 48).unwrap();
        assert_eq!(home.set("Text", 48), Err("Failed".into()));
        home.write("system/A/cursors/left_ptr", "broken by now");
        assert_eq!(home.set("A", 48), Err("Failed".into()));
        assert_eq!(home.names(OWN), ["default", "kaerice-cursor-A-48"]);
        assert!(home.exists("home/.icons/default/cursors/left_ptr"));
    }
}
