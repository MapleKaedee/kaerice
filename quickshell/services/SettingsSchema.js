.pragma library
.import "BarLayout.js" as BarLayout

// Every setting: its default, and a check returning true for usable values. Pure, so tests/tst_settings.qml can
// check it. settings.json is one flat object that holds only values differing from the default.
function int(min, max) { return v => Number.isInteger(v) && v >= min && v <= max; }
function bool(v) { return typeof v === "boolean"; }
function oneOf(values) { return v => values.includes(v); }
function color(v) { return typeof v === "string" && /^#[0-9a-f]{6}$/i.test(v); }
// seconds, 0 = never; the order of the stages is kept by the Power page (IdleStages.js)
function idle(v) { return v === 0 || int(30, 86400)(v); }

// no bottom-center: the volume OSD is there
const positions = ["top-left", "top-center", "top-right", "bottom-left", "bottom-right"];

const schema = {
    "theme.dark": { def: false, ok: bool },                      // the shell only; apps: AppTheme
    "theme.accent": { def: "#e8335a", ok: color },
    "theme.radius": { def: 8, ok: int(0, 16) },                  // px
    "theme.border": { def: 3, ok: int(1, 5) },                   // px
    "theme.shadow": { def: 4, ok: int(0, 8) },                   // px
    "bar.position": { def: "top", ok: oneOf(["top", "bottom"]) },
    "bar.size": { def: 38, ok: int(28, 48) },                    // px, height of a card
    "bar.monitor": { def: "all", ok: v => typeof v === "string" && /^[\w.-]{1,32}$/.test(v) }, // "all" or a name, e.g. DP-1
    "bar.cards": { def: BarLayout.defaults, ok: BarLayout.valid },
    "sound.volumeStep": { def: 3, ok: int(1, 20) },              // percent per key press or scroll
    "sound.visualizer": { def: true, ok: bool },                 // cava behind the bar while music plays
    "idle.dim": { def: 150, ok: idle },
    "idle.lock": { def: 300, ok: idle },
    "idle.screenOff": { def: 330, ok: idle },
    "idle.suspend": { def: 1800, ok: idle },                     // on battery only
    "power.hold": { def: 1000, ok: int(0, 5000) },               // ms to hold an action in the power menu, 0 = no hold
    "notifications.timeout": { def: 5000, ok: int(1000, 30000) }, // ms a popup stays
    "notifications.position": { def: "top-right", ok: oneOf(positions) }
};

function defaults() {
    const out = {};
    for (const key in schema) out[key] = schema[key].def;
    return out;
}

// text of settings.json -> { values, unknown, problems }. Bad values fall back to their default and are named in
// problems; keys this version does not know are kept, so an older checkout does not erase newer settings.
function load(text) {
    const out = { values: defaults(), unknown: {}, problems: [] };
    if (!text.trim()) return out;
    let data;
    try { data = JSON.parse(text); } catch (e) { data = null; }
    if (data === null || typeof data !== "object" || Array.isArray(data)) {
        out.problems.push("the file is not a JSON object");
        return out;
    }
    for (const key in data) {
        if (!schema.hasOwnProperty(key)) out.unknown[key] = data[key];
        else if (schema[key].ok(data[key])) out.values[key] = data[key];
        else out.problems.push(key);
    }
    return out;
}

function dump(values, unknown) {
    const out = {};
    for (const key in schema) if (values[key] !== schema[key].def) out[key] = values[key];
    for (const key in unknown) out[key] = unknown[key];
    return JSON.stringify(out, null, 4) + "\n";
}
