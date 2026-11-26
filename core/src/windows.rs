//! Windows cursors: .cur, .ani and the install.inf of a pack. They are downloads: nothing here may index by what they
//! say or overflow.

use std::collections::HashMap;
use std::io::Cursor;

use png::{ColorType, Decoder, Limits, Transformations};

use crate::cursor::{BYTES, Image, SIDE, bytes};

/// The most steps of an animation.
const STEPS: usize = 1024;

/// The shapes in the order of a Windows scheme: the name of the file, and the other names that apps ask for.
pub const ROLES: [(&str, &[&str]); 17] = [
    (
        "left_ptr",
        &[
            "default",
            "arrow",
            "top_left_arrow",
            "right_ptr",
            "center_ptr",
            "X_cursor",
            "context-menu",
            "copy",
            "alias",
            "dnd-copy",
            "dnd-link",
            "dnd-ask",
            "link",
            "zoom-in",
            "zoom-out",
            "1081e37283d90000800003c07f3ef6bf",
            "6407b0e94181790501fd1e167b474872",
            "b66166c04f8c3109214a4fbd64a50fc8",
            "3085a0e285430894940527032f8b26df",
            "640fb0e74195791501fd1ed57b41487f",
            "a2a266d0498c3104214a47bd64ab0fc8",
        ],
    ),
    (
        "help",
        &[
            "question_arrow",
            "whats_this",
            "left_ptr_help",
            "5c6cd98b3f3ebcb1f9c7f1c204630408",
            "d9ce0ab605698f320427677b458ad60b",
        ],
    ),
    (
        "progress",
        &[
            "left_ptr_watch",
            "half-busy",
            "00000000000000020006000e7e9ffc3f",
            "08e8e1c95fe2fc01f976f1e063a24ccd",
            "3ecb610c1bf2410f44200f48c40d3599",
        ],
    ),
    ("wait", &["watch"]),
    (
        "crosshair",
        &[
            "cross",
            "cross_reverse",
            "diamond_cross",
            "tcross",
            "cell",
            "plus",
        ],
    ),
    ("text", &["xterm", "ibeam", "vertical-text"]),
    ("pencil", &["draft"]),
    (
        "not-allowed",
        &[
            "no-drop",
            "crossed_circle",
            "forbidden",
            "circle",
            "dnd-none",
            "dnd-no-drop",
            "03b6e0fcb3499374a867c041f52298f0",
        ],
    ),
    (
        "ns-resize",
        &[
            "n-resize",
            "s-resize",
            "row-resize",
            "sb_v_double_arrow",
            "v_double_arrow",
            "double_arrow",
            "size_ver",
            "split_v",
            "top_side",
            "bottom_side",
            "00008160000006810000408080010102",
            "2870a09082c103050810ffdffffe0204",
        ],
    ),
    (
        "ew-resize",
        &[
            "e-resize",
            "w-resize",
            "col-resize",
            "sb_h_double_arrow",
            "h_double_arrow",
            "size_hor",
            "split_h",
            "left_side",
            "right_side",
            "028006030e0e7ebffc7f7070c0600140",
            "14fef782d02440884392942c11205230",
        ],
    ),
    (
        "nwse-resize",
        &[
            "nw-resize",
            "se-resize",
            "bd_double_arrow",
            "size_fdiag",
            "top_left_corner",
            "bottom_right_corner",
            "c7088f0f3e6c8088236ef8e1e3e70000",
        ],
    ),
    (
        "nesw-resize",
        &[
            "ne-resize",
            "sw-resize",
            "fd_double_arrow",
            "size_bdiag",
            "top_right_corner",
            "bottom_left_corner",
            "fcf1c3c7cd4491d801f1e1c78f100000",
        ],
    ),
    (
        "move",
        &[
            "fleur",
            "size_all",
            "all-scroll",
            "all-resize",
            "dnd-move",
            "grab",
            "grabbing",
            "openhand",
            "closedhand",
            "4498f0e0c1937ffe01fd06f973665830",
            "9081237383d90e509aa00f00170e968f",
            "fcf21c00b30f7e3f83fe0dfd12e71cff",
        ],
    ),
    ("sb_up_arrow", &["up_arrow", "up-arrow"]),
    (
        "pointer",
        &[
            "hand1",
            "hand2",
            "pointing_hand",
            "9d800788f1b08800ae810202380a0822",
            "e29285e634086352946a0e7090d73106",
        ],
    ),
    ("pin", &[]),
    ("person", &[]),
];

/// File names that packs use for the shapes, in the same order.
const NAMES: [&[&str]; 17] = [
    &["normal", "arrow", "pointer", "default"],
    &["help"],
    &[
        "working",
        "workinginbackground",
        "background",
        "appstarting",
        "work",
    ],
    &["busy", "wait", "loading"],
    &["precision", "crosshair", "cross"],
    &["text", "ibeam", "beam"],
    &["handwriting", "handwrite", "pen", "nwpen"],
    &[
        "unavailable",
        "unavailiable",
        "no",
        "notallowed",
        "forbidden",
    ],
    &["vertical", "vert", "sizens", "ns"],
    &["horizontal", "horz", "sizewe", "we", "ew"],
    &["diagonal1", "dgn1", "sizenwse", "nwse"],
    &["diagonal2", "dgn2", "sizenesw", "nesw"],
    &["move", "sizeall"],
    &["alternate", "uparrow", "up"],
    &["link", "hand"],
    &["pin", "location"],
    &["person"],
];

/// The shape that a file name stands for.
pub fn guess(file_name: &str) -> Option<usize> {
    let stem = file_name.rsplit_once('.')?.0.to_lowercase();
    let letters: String = stem.chars().filter(char::is_ascii_lowercase).collect();
    let mut name = ["select", "resize"]
        .iter()
        .find_map(|end| letters.strip_suffix(end))
        .unwrap_or(&letters)
        .to_owned();
    if name == "diagonal" || name == "dgn" {
        name.extend(stem.chars().last());
    }
    NAMES
        .iter()
        .position(|names| names.contains(&name.as_str()))
}

pub struct Scheme {
    pub name: Option<String>,
    /// The file of each shape.
    pub files: [Option<String>; 17],
}

/// The scheme of an install.inf. Many are broken ("%%horz%"), so this looks only for what it needs.
pub fn scheme(inf: &[u8]) -> Option<Scheme> {
    let text = text(inf);
    let mut strings = HashMap::new();
    let (mut value, mut name) = (None, None);
    let mut in_strings = false;
    for line in text.lines().map(str::trim) {
        if line.starts_with('[') {
            in_strings = line.to_lowercase().starts_with("[strings");
        } else if line
            .to_lowercase()
            .contains("control panel\\cursors\\schemes")
        {
            // HKCU,"path","name",,"file,file,..."
            let quoted: Vec<_> = line.split('"').skip(1).step_by(2).collect();
            if let [_, first, .., last] = quoted[..] {
                (name, value) = (Some(first), Some(last));
            }
        } else if in_strings && let Some((key, value)) = line.split_once('=') {
            let value = value.trim().trim_matches('"');
            strings.insert(key.trim().to_lowercase(), value.to_owned());
        }
    }
    let resolve = |text: &str| {
        let last = text.rsplit(['\\', '/']).next().unwrap_or_default();
        let last = last.trim_matches(|c: char| c == '%' || c.is_whitespace());
        let known = strings.get(&last.to_lowercase()).cloned();
        Some(known.unwrap_or_else(|| last.to_owned())).filter(|name| !name.is_empty())
    };
    let mut files = value?.split(',').map(resolve);
    Some(Scheme {
        name: name.and_then(resolve),
        files: std::array::from_fn(|_| files.next().flatten()),
    })
}

fn text(data: &[u8]) -> String {
    let wide = |data: &[u8], word: fn([u8; 2]) -> u16| {
        let words = data.as_chunks().0.iter().map(|pair| word(*pair));
        let chars = char::decode_utf16(words).map(|c| c.unwrap_or(char::REPLACEMENT_CHARACTER));
        chars.collect()
    };
    match data {
        [0xff, 0xfe, data @ ..] => wide(data, u16::from_le_bytes),
        [0xfe, 0xff, data @ ..] => wide(data, u16::from_be_bytes),
        [0xef, 0xbb, 0xbf, data @ ..] | data => String::from_utf8_lossy(data).into_owned(),
    }
}

/// The images of a .cur or .ani file, whatever it is called. Each picture is paid from `work` before it is read: its
/// bytes in the file, then its pixels. At most BYTES for one file.
pub fn read(file: &[u8], work: &mut u64) -> Option<Vec<Image>> {
    let start = (*work).min(BYTES);
    let mut left = start;
    let images = match file.get(..4)? {
        b"RIFF" => ani(file, &mut left),
        _ => cur(file, &mut left),
    };
    *work -= start - left;
    images
}

fn take(left: &mut u64, n: usize) -> Option<()> {
    *left = left.checked_sub(n as u64)?;
    Some(())
}

fn half(data: &[u8], at: usize) -> Option<u32> {
    let bytes = data.get(at..)?.get(..2)?.try_into().ok()?;
    Some(u16::from_le_bytes(bytes).into())
}

fn word(data: &[u8], at: usize) -> Option<u32> {
    let bytes = data.get(at..)?.get(..4)?.try_into().ok()?;
    Some(u32::from_le_bytes(bytes))
}

fn ani(file: &[u8], left: &mut u64) -> Option<Vec<Image>> {
    if file.get(8..12)? != b"ACON" {
        return None;
    }
    let (mut header, mut rates, mut steps, mut icons) = (None, None, None, Vec::new());
    for (name, data) in chunks(file.get(12..)?) {
        let words = || data.as_chunks().0.iter().map(|w| u32::from_le_bytes(*w));
        match name {
            b"anih" => header = Some(data),
            b"rate" => rates = Some(words().collect::<Vec<_>>()),
            b"seq " => steps = Some(words().map(|w| w as usize).collect::<Vec<_>>()),
            b"LIST" if data.starts_with(b"fram") => {
                let frames = chunks(data.get(4..)?).into_iter();
                icons.extend(frames.filter(|(name, _)| *name == b"icon").map(|f| f.1));
            }
            _ => {}
        }
    }
    let header = header?;
    let (count, rate, flags) = (word(header, 4)?, word(header, 28)?, word(header, 32)?);
    // without this flag the frames are bare pixels
    if flags & 1 == 0 || icons.len() < count as usize || icons.len() > STEPS {
        return None;
    }
    let steps = steps.unwrap_or_else(|| (0..icons.len()).collect());
    if steps.len() > STEPS {
        return None;
    }
    let icons: Vec<_> = icons.into_iter().map(|icon| cur(icon, left)).collect();
    let mut images = Vec::new();
    for (i, step) in steps.into_iter().enumerate() {
        let jiffies = rates.as_ref().and_then(|r| r.get(i).copied());
        // 60 in a second; the shell and Hyprland would not move on from 0
        let delay = match u64::from(jiffies.unwrap_or(rate)) * 1000 / 60 {
            0 => 100,
            ms => ms.min(60_000) as u32,
        };
        for image in icons.get(step)?.as_ref()? {
            take(left, image.pixels.len())?;
            images.push(Image {
                delay,
                pixels: image.pixels.clone(),
                ..*image
            });
        }
    }
    (!images.is_empty()).then_some(images)
}

/// Those that are whole: the length in the header of the file is often wrong.
fn chunks(mut data: &[u8]) -> Vec<(&[u8; 4], &[u8])> {
    let mut chunks = Vec::new();
    while let Some((name, rest)) = data.split_first_chunk::<4>()
        && let Some((length, rest)) = rest.split_first_chunk::<4>()
        && let length = u32::from_le_bytes(*length) as usize
        && let Some(chunk) = rest.get(..length)
    {
        chunks.push((name, chunk));
        data = rest.get(length + length % 2..).unwrap_or_default();
    }
    chunks
}

fn cur(file: &[u8], left: &mut u64) -> Option<Vec<Image>> {
    let kind = half(file, 2)?;
    if half(file, 0)? != 0 || !(1..=2).contains(&kind) {
        return None;
    }
    let mut best: Vec<(u32, Image)> = Vec::new();
    for i in 0..half(file, 4)?.min(64) as usize {
        let at = 6 + 16 * i;
        let data = (|| {
            let (length, offset) = (word(file, at + 8)?, word(file, at + 12)?);
            file.get(offset as usize..)?.get(..length as usize)
        })();
        // many entries may lead to one picture
        let picture = |data: &[u8]| {
            take(left, data.len())?;
            picture(data, left).or_else(|| bitmap(data, left))
        };
        let Some((width, height, bits, pixels)) = data.and_then(picture) else {
            continue;
        };
        // an icon has something else there
        let hot = |at: usize| if kind == 2 { half(file, at) } else { Some(0) };
        let image = Image {
            size: width.max(height),
            width,
            height,
            xhot: hot(at + 4)?,
            yhot: hot(at + 6)?,
            delay: 0,
            pixels,
        };
        // the same size again is a poorer copy; as a second image it would be an animation
        match best.iter_mut().find(|(_, other)| other.size == image.size) {
            Some(other) if bits > other.0 => *other = (bits, image),
            Some(_) => {}
            None => best.push((bits, image)),
        }
    }
    let images: Vec<_> = best.into_iter().map(|(_, image)| image).collect();
    (!images.is_empty()).then_some(images)
}

fn premultiplied([r, g, b, a]: [u8; 4]) -> [u8; 4] {
    let times = |c: u8| ((u32::from(c) * u32::from(a) + 127) / 255) as u8;
    [times(b), times(g), times(r), a]
}

/// width, height, bits, pixels
type Picture = (u32, u32, u32, Vec<u8>);

fn picture(data: &[u8], left: &mut u64) -> Option<Picture> {
    if !data.starts_with(b"\x89PNG") {
        return None;
    }
    let limits = Limits {
        bytes: BYTES as usize,
    };
    let mut decoder = Decoder::new_with_limits(Cursor::new(data), limits);
    decoder.set_transformations(Transformations::normalize_to_color8());
    let mut reader = decoder.read_info().ok()?;
    let (width, height) = (reader.info().width, reader.info().height);
    if !(1..=SIDE).contains(&width) || !(1..=SIDE).contains(&height) {
        return None;
    }
    take(left, bytes(width, height))?;
    let mut buffer = vec![0; reader.output_buffer_size()?];
    let frame = reader.next_frame(&mut buffer).ok()?;
    let data = buffer.get(..frame.buffer_size())?;
    let pixels = match frame.color_type {
        ColorType::Rgba => (data.as_chunks::<4>().0.iter())
            .flat_map(|p| premultiplied(*p))
            .collect(),
        ColorType::Rgb => (data.as_chunks::<3>().0.iter())
            .flat_map(|[r, g, b]| [*b, *g, *r, 255])
            .collect(),
        ColorType::GrayscaleAlpha => (data.as_chunks::<2>().0.iter())
            .flat_map(|[v, a]| premultiplied([*v, *v, *v, *a]))
            .collect(),
        ColorType::Grayscale => data.iter().flat_map(|v| [*v, *v, *v, 255]).collect(),
        ColorType::Indexed => return None,
    };
    Some((width, height, 32, pixels))
}

fn bitmap(data: &[u8], left: &mut u64) -> Option<Picture> {
    let header = word(data, 0)? as usize;
    let (width, both) = (word(data, 4)?, word(data, 8)?);
    // the picture and its mask, one above the other
    let height = both / 2;
    let (bits, packed, colors) = (half(data, 14)?, word(data, 16)?, word(data, 32)?);
    if header < 40
        || packed != 0
        || !(1..=SIDE).contains(&width)
        || !(1..=SIDE).contains(&height)
        || !matches!(bits, 1 | 4 | 8 | 24 | 32)
    {
        return None;
    }
    let colors = match (bits, colors) {
        (24 | 32, _) => 0,
        (_, 0) => 1 << bits,
        (_, colors) if colors <= 256 => colors as usize,
        _ => return None,
    };
    let (w, h) = (width as usize, height as usize);
    let stride = |bits: usize| (w * bits).div_ceil(32) * 4;
    let (row, mask_row) = (stride(bits as usize), stride(1));
    let rest = data.get(header..)?;
    let palette = rest.get(..4 * colors)?;
    let rest = rest.get(4 * colors..)?;
    let rows = rest.get(..row * h)?;
    let mask = rest.get(row * h..)?.get(..mask_row * h);
    let alpha = bits == 32 && rows.as_chunks::<4>().0.iter().any(|p| p[3] != 0);
    if !alpha && mask.is_none() {
        return None;
    }
    take(left, bytes(width, height))?;

    let mut pixels = Vec::with_capacity(bytes(width, height));
    // from the bottom up
    for y in (0..h).rev() {
        let line = rows.get(y * row..)?;
        for x in 0..w {
            let byte = |at: usize| line.get(at).copied();
            let indexed = |i: usize| palette.get(4 * i..)?.get(..3)?.try_into().ok();
            let bgr: [u8; 3] = match bits {
                1 => indexed((byte(x / 8)? >> (7 - x % 8) & 1).into())?,
                4 => indexed((byte(x / 2)? >> (4 - x % 2 * 4) & 15).into())?,
                8 => indexed(byte(x)?.into())?,
                24 => [byte(3 * x)?, byte(3 * x + 1)?, byte(3 * x + 2)?],
                _ => [byte(4 * x)?, byte(4 * x + 1)?, byte(4 * x + 2)?],
            };
            let [b, g, r] = bgr;
            let masked = || Some(mask?.get(y * mask_row + x / 8)? >> (7 - x % 8) & 1 == 1);
            pixels.extend(if alpha {
                premultiplied([r, g, b, byte(4 * x + 3)?])
            } else if !masked()? {
                [b, g, r, 255]
            } else if bgr == [0; 3] {
                [0; 4]
            } else {
                // Windows turns the color of the screen around there
                [0, 0, 0, 255]
            });
        }
    }
    Some((width, height, bits, pixels))
}

#[cfg(test)]
pub mod tests {
    use super::*;

    const RED: [u8; 4] = [0, 0, 255, 255];
    const GREEN: [u8; 4] = [0, 255, 0, 255];
    const BLUE: [u8; 4] = [255, 0, 0, 255];
    const BLACK: [u8; 4] = [0, 0, 0, 255];
    const CLEAR: [u8; 4] = [0; 4];
    /// Blue, green, red, unused.
    const PALETTE: [[u8; 4]; 4] = [[0, 0, 0, 0], [0, 0, 255, 0], [0, 255, 0, 0], [255, 0, 0, 0]];

    /// Rows from the top; they are padded and turned around here.
    fn dib(
        width: i32,
        height: i32,
        bits: u16,
        palette: &[[u8; 4]],
        rows: &[&[u8]],
        mask: &[u8],
    ) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend(40u32.to_le_bytes());
        out.extend(width.to_le_bytes());
        out.extend((2 * height).to_le_bytes());
        out.extend(1u16.to_le_bytes());
        out.extend(bits.to_le_bytes());
        out.extend([0; 16]);
        out.extend((palette.len() as u32).to_le_bytes());
        out.extend([0; 4]);
        out.extend(palette.concat());
        for row in rows.iter().rev() {
            out.extend(*row);
            out.resize(out.len().next_multiple_of(4), 0);
        }
        for row in mask.iter().rev() {
            out.extend([*row, 0, 0, 0]);
        }
        out
    }

    /// (width, height, xhot, yhot, image)
    fn cur(images: &[(u8, u8, u16, u16, Vec<u8>)]) -> Vec<u8> {
        let mut out = vec![0, 0, 2, 0, images.len() as u8, 0];
        let mut at = 6 + 16 * images.len();
        for (w, h, x, y, data) in images {
            out.extend([*w, *h, 0, 0]);
            out.extend(x.to_le_bytes());
            out.extend(y.to_le_bytes());
            out.extend((data.len() as u32).to_le_bytes());
            out.extend((at as u32).to_le_bytes());
            at += data.len();
        }
        for (.., data) in images {
            out.extend(data);
        }
        out
    }

    /// One color, 8 bits, hotspot 1, 2.
    pub fn plain(side: u8, color: u8) -> Vec<u8> {
        let row = vec![color; side as usize];
        let rows = vec![row.as_slice(); side as usize];
        let mut data = dib(side.into(), side.into(), 8, &PALETTE, &rows, &[]);
        let mask = (usize::from(side)).div_ceil(32) * 4 * usize::from(side);
        data.resize(data.len() + mask, 0);
        cur(&[(side, side, 1, 2, data)])
    }

    fn chunk(name: &[u8; 4], data: &[u8]) -> Vec<u8> {
        let mut out = name.to_vec();
        out.extend((data.len() as u32).to_le_bytes());
        out.extend(data);
        out.resize(out.len().next_multiple_of(2), 0);
        out
    }

    fn words(words: &[u32]) -> Vec<u8> {
        words.iter().flat_map(|w| w.to_le_bytes()).collect()
    }

    /// 6 jiffies for each step unless there is a rate.
    pub fn ani(steps: u32, extra: &[Vec<u8>], icons: &[Vec<u8>]) -> Vec<u8> {
        let header = [36, icons.len() as u32, steps, 0, 0, 0, 0, 6, 1];
        let mut body = b"ACON".to_vec();
        body.extend(chunk(b"anih", &words(&header)));
        body.extend(extra.concat());
        let mut list = b"fram".to_vec();
        for icon in icons {
            list.extend(chunk(b"icon", icon));
        }
        body.extend(chunk(b"LIST", &list));
        chunk(b"RIFF", &body)
    }

    fn pixels(image: &Image) -> Vec<[u8; 4]> {
        let pixels = image.pixels.chunks(4);
        pixels.map(|p| p.try_into().unwrap()).collect()
    }

    const MASK: [u8; 2] = [0b0010_0000, 0b0100_0000];

    #[test]
    fn every_depth_is_read() {
        let colors = [RED, GREEN, CLEAR, BLUE, CLEAR, RED];
        for (bits, palette, rows) in [
            (4, &PALETTE[..], [&[0x12, 0x00][..], &[0x30, 0x10][..]]),
            (8, &PALETTE[..], [&[1, 2, 0][..], &[3, 0, 1][..]]),
            (
                24,
                &[][..],
                [
                    &[0, 0, 255, 0, 255, 0, 0, 0, 0][..],
                    &[255, 0, 0, 0, 0, 0, 0, 0, 255][..],
                ],
            ),
            (
                32,
                &[][..],
                [
                    &[0, 0, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0][..],
                    &[255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0][..],
                ],
            ),
        ] {
            let data = dib(3, 2, bits, palette, &rows, &MASK);
            let images = read(&cur(&[(3, 2, 2, 1, data)])).unwrap();
            let i = &images[0];
            let facts = (i.size, i.width, i.height, i.xhot, i.yhot, i.delay);
            assert_eq!(facts, (3, 3, 2, 2, 1, 0), "{bits}");
            assert_eq!(pixels(i), colors, "{bits}");
        }
        let rows = [&[0b1000_0000][..], &[0b0010_0000][..]];
        let data = dib(3, 2, 1, &PALETTE[..2], &rows, &MASK);
        let images = read(&cur(&[(3, 2, 0, 0, data)])).unwrap();
        assert_eq!(pixels(&images[0]), [RED, BLACK, CLEAR, BLACK, CLEAR, RED]);
    }

    #[test]
    fn inverted_pixels_are_black() {
        let rows = [&[1, 0, 1][..]];
        let data = dib(3, 1, 8, &PALETTE, &rows, &[0b1100_0000]);
        let images = read(&cur(&[(3, 1, 0, 0, data)])).unwrap();
        assert_eq!(pixels(&images[0]), [BLACK, CLEAR, RED]);
    }

    #[test]
    fn alpha_wins_over_the_mask() {
        let rows = [&[100, 50, 200, 128, 9, 9, 9, 0][..]];
        let data = dib(2, 1, 32, &[], &rows, &[0b1100_0000]);
        let images = read(&cur(&[(2, 1, 0, 0, data.clone())])).unwrap();
        assert_eq!(pixels(&images[0]), [[50, 25, 100, 128], CLEAR]);
        // some have no mask then
        let images = read(&cur(&[(2, 1, 0, 0, data[..48].to_vec())])).unwrap();
        assert_eq!(pixels(&images[0]), [[50, 25, 100, 128], CLEAR]);
    }

    /// Without a budget.
    fn read(file: &[u8]) -> Option<Vec<Image>> {
        let mut work = u64::MAX;
        super::read(file, &mut work)
    }

    #[test]
    fn decoding_takes_from_a_budget() {
        let file = plain(32, 1);
        // the picture as it is in the file, then its pixels
        let need = (file.len() - 22 + bytes(32, 32)) as u64;
        assert!(super::read(&file, &mut (need - 1)).is_none());
        let mut work = need + 5;
        assert!(super::read(&file, &mut work).is_some());
        assert_eq!(work, 5);
    }

    #[test]
    fn a_file_decodes_at_most_its_own_bytes() {
        // a quarter of a megabyte of pixels in a few hundred bytes
        let data = vec![0; 256 * 256];
        let frame = cur(&[(
            0,
            0,
            0,
            0,
            png_of(256, 256, png::ColorType::Grayscale, None, &data),
        )]);
        let mut work = u64::MAX;
        assert!(super::read(&ani(257, &[], &vec![frame; 257]), &mut work).is_none());
        assert!((BYTES - 1_000_000..=BYTES).contains(&(u64::MAX - work)));
    }

    #[test]
    fn every_step_of_an_animation_is_paid() {
        let icon = plain(32, 1);
        let mut once = u64::MAX;
        super::read(&icon, &mut once).unwrap();
        // one small picture shown many times
        let seq = chunk(b"seq ", &words(&[0; 10]));
        let mut work = u64::MAX;
        let images = super::read(&ani(10, &[seq], &[icon]), &mut work).unwrap();
        assert_eq!(images.len(), 10);
        assert_eq!(work, once - 10 * bytes(32, 32) as u64);
    }

    fn png(color: png::ColorType, palette: Option<&[u8]>, data: &[u8]) -> Vec<u8> {
        png_of(2, 1, color, palette, data)
    }

    fn png_of(
        width: u32,
        height: u32,
        color: png::ColorType,
        palette: Option<&[u8]>,
        data: &[u8],
    ) -> Vec<u8> {
        let mut out = Vec::new();
        let mut encoder = png::Encoder::new(&mut out, width, height);
        encoder.set_color(color);
        if let Some(palette) = palette {
            encoder.set_palette(palette);
        }
        let mut writer = encoder.write_header().unwrap();
        writer.write_image_data(data).unwrap();
        writer.finish().unwrap();
        out
    }

    #[test]
    fn png_images_are_read() {
        use png::ColorType::*;
        let half = [[50, 25, 100, 128], RED];
        let rgba = png(Rgba, None, &[200, 50, 100, 128, 255, 0, 0, 255]);
        let indexed = png(Indexed, Some(&[0, 255, 0, 255, 0, 0]), &[0, 1]);
        for (data, colors) in [
            (rgba, half),
            (png(Rgb, None, &[0, 255, 0, 255, 0, 0]), [GREEN, RED]),
            (indexed, [GREEN, RED]),
            (png(GrayscaleAlpha, None, &[0, 255, 0, 0]), [BLACK, CLEAR]),
            (png(Grayscale, None, &[0, 255]), [BLACK, [255; 4]]),
        ] {
            let images = read(&cur(&[(2, 1, 1, 0, data)])).unwrap();
            assert_eq!((images[0].width, images[0].height), (2, 1));
            assert_eq!(pixels(&images[0]), colors);
        }
    }

    #[test]
    fn all_sizes_are_kept_each_once() {
        let (small, big) = (plain(32, 1), plain(48, 2));
        let poor = dib(32, 32, 1, &PALETTE[..2], &vec![&[0u8; 4][..]; 32], &[0; 32]);
        let file = cur(&[
            (32, 32, 0, 0, poor),
            (32, 32, 1, 1, small[22..].to_vec()),
            (48, 48, 2, 2, big[22..].to_vec()),
        ]);
        let images = read(&file).unwrap();
        let facts: Vec<_> = images.iter().map(|i| (i.size, i.xhot)).collect();
        assert_eq!(facts, [(32, 1), (48, 2)]);
        assert_eq!(pixels(&images[0])[0], RED);
        assert_eq!(pixels(&images[1])[0], GREEN);
    }

    #[test]
    fn an_animation_follows_rate_and_seq() {
        let rate = chunk(b"rate", &words(&[6, 12, 0]));
        let seq = chunk(b"seq ", &words(&[0, 1, 1]));
        let file = ani(3, &[rate, seq], &[plain(32, 1), plain(32, 2)]);
        let images = read(&file).unwrap();
        let facts: Vec<_> = images
            .iter()
            .map(|i| (i.delay, i.xhot, i.yhot, pixels(i)[0]))
            .collect();
        assert_eq!(
            facts,
            [(100, 1, 2, RED), (200, 1, 2, GREEN), (100, 1, 2, GREEN)]
        );
    }

    #[test]
    fn an_animation_without_them_uses_the_header() {
        let info = chunk(b"LIST", b"INFOINAM\x03\0\0\0abc\0");
        let images = read(&ani(2, &[info], &[plain(32, 3), plain(32, 1)])).unwrap();
        let facts: Vec<_> = images.iter().map(|i| (i.delay, pixels(i)[0])).collect();
        assert_eq!(facts, [(100, BLUE), (100, RED)]);
    }

    #[test]
    fn an_icon_has_no_hotspot() {
        let mut icon = plain(32, 1);
        icon[2] = 1;
        assert_eq!(read(&icon).unwrap()[0].xhot, 0);
    }

    #[test]
    fn broken_files_are_none() {
        let good = plain(32, 1);
        let moving = ani(2, &[], &[plain(32, 1), plain(32, 2)]);
        let picture = cur(&[(2, 1, 0, 0, png(png::ColorType::Rgb, None, &[0; 6]))]);
        for file in [&good, &moving, &picture] {
            assert!(read(file).is_some());
            for n in 0..file.len() {
                assert!(read(&file[..n]).is_none(), "{n} of {}", file.len());
            }
        }
        assert!(read(b"MZ not a cursor, and long enough for a header").is_none());
        // in the .cur: type, count, length, offset; in its image: header, width, height, bits, compression, colors
        for (at, value) in [
            (2, 7),
            (4, 0),
            (14, 10),
            (18, u32::MAX),
            (22, 12),
            (26, 0),
            (26, 2000),
            (26, u32::MAX),
            (30, 0),
            (30, u32::MAX - 63),
            (30, 4000),
            (36, 16),
            (38, 1),
            (54, 1),
            (54, 300),
        ] {
            let mut bad = good.clone();
            let bytes = u32::to_le_bytes(value);
            let length = if matches!(at, 2 | 4 | 36) { 2 } else { 4 };
            bad[at..at + length].copy_from_slice(&bytes[..length]);
            assert!(read(&bad).is_none(), "{value} at {at}");
        }
        // frames as raw pixels, a step without its frame, no steps, too many
        let mut raw = moving.clone();
        raw[20 + 32] = 0;
        assert!(read(&raw).is_none());
        let seq = |steps: &[u32]| chunk(b"seq ", &words(steps));
        for steps in [&[0, 2][..], &[][..], &[0; 2000][..]] {
            assert!(read(&ani(2, &[seq(steps)], &[plain(32, 1)])).is_none());
        }
    }

    #[test]
    fn a_scheme_is_read() {
        let inf = concat!(
            "[Version]\r\nsignature=\"$CHICAGO$\"\r\n[Scheme.Reg]\r\n",
            "hkcu,\"Control Panel\\Cursors\\Schemes\",\"%SCHEME_NAME%\",,\"",
            "%10%\\%CUR_DIR%\\%pointer%,%10%\\%CUR_DIR%\\Help.ani,,%10%\\%CUR_DIR%\\%%horz%,x\\%Nothing%\"\r\n",
            "; pointer = \"comment.ani\"\r\n[Strings]\r\n",
            "CUR_DIR = \"Cursors\\Pack\"\r\nscheme_name = \"My Pack\"\r\nPointer = \"Normal.ani\"\r\nhorz=Horizontal.ani\r\n",
        );
        let scheme = scheme(inf.as_bytes()).unwrap();
        assert_eq!(scheme.name.as_deref(), Some("My Pack"));
        let files = scheme.files.iter().map(|f| f.as_deref().unwrap_or("-"));
        let files: Vec<_> = files.take(6).collect();
        assert_eq!(
            files,
            [
                "Normal.ani",
                "Help.ani",
                "-",
                "Horizontal.ani",
                "Nothing",
                "-"
            ]
        );
    }

    #[test]
    fn a_scheme_may_be_utf16_or_missing() {
        let inf = "[S]\nHKCU,\"Control Panel\\Cursors\\Schemes\",\"Näme\",,\"a\\b.cur\"\n";
        let mut utf16 = vec![0xff, 0xfe];
        utf16.extend(inf.encode_utf16().flat_map(u16::to_le_bytes));
        let mut big = vec![0xfe, 0xff];
        big.extend(inf.encode_utf16().flat_map(u16::to_be_bytes));
        let mut utf8 = vec![0xef, 0xbb, 0xbf];
        utf8.extend(inf.as_bytes());
        for text in [&utf16, &big, &utf8] {
            let scheme = scheme(text).unwrap();
            assert_eq!(scheme.name.as_deref(), Some("Näme"));
            assert_eq!(scheme.files[0].as_deref(), Some("b.cur"));
        }
        assert!(scheme(b"[Version]\nsignature=x\n").is_none());
        assert!(scheme(b"HKCU,\"Control Panel\\Cursors\\Schemes\",\"x\"\n").is_none());
    }

    #[test]
    fn names_are_guessed() {
        for (name, role) in [
            ("Normal Select.cur", Some(0)),
            ("arrow.ani", Some(0)),
            ("help.ani", Some(1)),
            ("Working in Background.ani", Some(2)),
            ("01-Busy.ani", Some(3)),
            ("precision_select.cur", Some(4)),
            ("Text 2.cur", Some(5)),
            ("Handwriting.cur", Some(6)),
            ("Unavailiable.ani", Some(7)),
            ("Vertical Resize.cur", Some(8)),
            ("horz.ani", Some(9)),
            ("Diagonal Resize 1.ani", Some(10)),
            ("dgn2.ani", Some(11)),
            ("MOVE.CUR", Some(12)),
            ("Alternate Select.cur", Some(13)),
            ("LINK.CUR", Some(14)),
            ("Location Select.cur", Some(15)),
            ("person.cur", Some(16)),
            ("readme.cur", None),
            ("diagonal.cur", None),
            ("noextension", None),
            (".cur", None),
        ] {
            assert_eq!(guess(name), role, "{name}");
        }
    }

    #[test]
    fn every_name_of_adwaita_is_known() {
        let adwaita = "alias all-resize all-scroll arrow bd_double_arrow bottom_left_corner bottom_right_corner \
            bottom_side cell col-resize context-menu copy cross crosshair cross_reverse default diamond_cross dnd-ask \
            dnd-move e-resize ew-resize fd_double_arrow fleur grab grabbing hand1 hand2 help left_ptr left_side move \
            ne-resize nesw-resize no-drop not-allowed n-resize ns-resize nw-resize nwse-resize pointer progress \
            question_arrow right_side row-resize sb_h_double_arrow sb_v_double_arrow se-resize s-resize sw-resize tcross \
            text top_left_arrow top_left_corner top_right_corner top_side vertical-text wait watch w-resize X_cursor \
            xterm zoom-in zoom-out";
        let mut names: Vec<_> = ROLES
            .iter()
            .flat_map(|(file, links)| [*file].into_iter().chain(links.iter().copied()))
            .collect();
        for name in adwaita.split_whitespace() {
            assert!(names.contains(&name), "{name}");
        }
        let all = names.len();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), all);
    }
}
