.pragma library

// wallhaven.cc API v1: search URLs, reading answers, saved filters. Pure, so tests/tst_wallhaven.qml can check it.
// API: https://wallhaven.cc/help/api
const base = "https://wallhaven.cc/api/v1/search?";
const checkUrl = base + "purity=001"; // answers 401 to a bad key

const sortings = ["toplist", "date_added", "random", "relevance"];
const sizes = ["", "1920x1080", "2560x1440", "3840x2160"]; // minimum, "" = any
const bits = /^(?!000)[01]{3}$/; // three switches, at least one on

// categories: general, anime, people. purity: sfw, sketchy, nsfw.
function loadFilters(text) {
    let d;
    try { d = JSON.parse(text); } catch (e) { d = null; }
    const pick = (v, ok, def) => typeof v === "string" && ok(v) ? v : def;
    return {
        categories: pick(d?.categories, v => bits.test(v), "111"),
        sorting: pick(d?.sorting, v => sortings.includes(v), "toplist"),
        atleast: pick(d?.atleast, v => sizes.includes(v), "1920x1080"),
        purity: pick(d?.purity, v => bits.test(v), "100")
    };
}

// flips switch i, but the last one stays on
function toggle(value, i) {
    const out = value.split("").map((b, n) => n === i ? (b === "1" ? "0" : "1") : b).join("");
    return bits.test(out) ? out : value;
}

// seed: from the first page of a random search, so later pages do not repeat it
function searchUrl(query, f, key, page, seed) {
    const p = { categories: f.categories, purity: key ? f.purity : "100", sorting: f.sorting, page: page };
    if (query.trim()) p.q = query.trim();
    if (f.sorting === "toplist") p.topRange = p.q ? "1y" : "1M"; // a month of one subject is only a few images
    if (f.atleast) p.atleast = f.atleast;
    if (f.sorting === "random" && seed && page > 1) p.seed = seed;
    return base + Object.keys(p).map(k => k + "=" + encodeURIComponent(p[k])).join("&");
}

// answer -> { items, page, lastPage, total, seed }, or null when unreadable. Items whose id or URLs are not what
// Wallhaven sends are left out: they become a file name and a download.
function parse(text) {
    let d;
    try { d = JSON.parse(text); } catch (e) { return null; }
    if (!Array.isArray(d?.data) || !d.meta) return null;
    const items = [];
    for (const i of d.data) {
        const file = /^https:\/\/w\.wallhaven\.cc\/full\/[a-z0-9]{2}\/wallhaven-([a-z0-9]{6})\.(?:jpg|jpeg|png|webp)$/.exec(i?.path ?? "");
        const thumb = i?.thumbs?.large ?? "";
        if (!file || file[1] !== i.id || !thumb.startsWith("https://th.wallhaven.cc/")) continue;
        items.push({ wid: i.id, full: i.path, thumb: thumb, purity: String(i.purity), category: String(i.category),
            resolution: String(i.resolution), size: Number(i.file_size) || 0 });
    }
    return { items: items, page: Number(d.meta.current_page) || 1, lastPage: Number(d.meta.last_page) || 1,
        total: Number(d.meta.total) || 0, seed: d.meta.seed ?? "" };
}

function fileName(url) { return url.split("/").pop(); }
// also finds files renamed by the site's download page, e.g. wallhaven-7jmgey_1920x1080.png
function isFileOf(name, wid) { return name.startsWith("wallhaven-" + wid + ".") || name.startsWith("wallhaven-" + wid + "_"); }

function isKey(text) { return /^[A-Za-z0-9]{16,64}$/.test(text); }

function errorText(status) {
    if (status === 0) return "No connection to Wallhaven.";
    if (status === 401) return "Wallhaven did not accept the API key.";
    if (status === 429) return "Too many requests. Wait a minute.";
    return "Wallhaven answered with an error (" + status + ").";
}
