.pragma library

// Every setting: its default, and a check returning true for usable values. Pure, so tests/tst_settings.qml can
// check it. settings.json is one flat object that holds only values differing from the default.
function int(min, max) { return v => Number.isInteger(v) && v >= min && v <= max; }

const schema = {
    "notifications.timeout": { def: 5000, ok: int(1000, 30000) } // ms a popup stays
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
