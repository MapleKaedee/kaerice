.pragma library

// `hyprctl devices -j` -> [{ name, capsLock, numLock }]; [] when it prints [] or an error text
function fromHyprland(json) {
    let keyboards;
    try { keyboards = JSON.parse(json).keyboards; } catch (e) {}
    return Array.isArray(keyboards) ? keyboards.map(k => ({ name: k.name, capsLock: k.capsLock, numLock: k.numLock })) : [];
}

// "<led> <brightness>" lines, e.g. "input3::capslock 1" -> [{ name: "input3", capsLock: true, numLock: false }]
function fromLeds(text) {
    const byName = {};
    const out = [];
    for (const line of text.split("\n")) {
        const m = /^(.+)::(capslock|numlock) (\d+)$/.exec(line.trim());
        if (!m) continue;
        if (!byName[m[1]]) { byName[m[1]] = { name: m[1], capsLock: false, numLock: false }; out.push(byName[m[1]]); }
        byName[m[1]][m[2] === "capslock" ? "capsLock" : "numLock"] = m[3] !== "0";
    }
    return out;
}
