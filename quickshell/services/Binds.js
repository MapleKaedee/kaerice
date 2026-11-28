.pragma library

// Keybinds of the compositor for the cheat sheet -> [{ group, action, combo: [key, ...] }]. The description is
// "Group: action": the hl.bind description on Hyprland, the comment line right above the bind on Mango.

const keyNames = {
    left: "←", right: "→", up: "↑", down: "↓", Return: "Enter", space: "Space", semicolon: ";", slash: "/", comma: ",",
    period: ".", bracketleft: "[", bracketright: "]", minus: "-", equal: "=", Page_Up: "PgUp", Page_Down: "PgDn",
    "mouse:272": "LMB", "mouse:273": "RMB", mouse_down: "Wheel ↓", mouse_up: "Wheel ↑",
    btn_left: "LMB", btn_right: "RMB", btn_middle: "MMB",
    XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol -", XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
    XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioPrev: "Prev", XF86AudioNext: "Next",
    Caps_Lock: "Caps Lock", Num_Lock: "Num Lock", Alt_L: "Left Alt", Alt_R: "Right Alt", XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright -"
};
const arrows = { up: "↑", down: "↓", left: "←", right: "→" };
const modOrder = ["SUPER", "CTRL", "ALT", "SHIFT"];

function keyName(key) {
    return keyNames[key] ?? keyNames[key.toLowerCase()] ?? (key.length === 1 ? key.toUpperCase() : key);
}

function row(desc, mods, key, shown) {
    const i = desc.indexOf(": ");
    // a bind on a modifier key carries that modifier too (Alt_L: ALT)
    const combo = modOrder.filter(m => mods.includes(m) && !key.toUpperCase().startsWith(m)).concat([shown]);
    return { group: i > 0 ? desc.slice(0, i) : "Other", action: i > 0 ? desc.slice(i + 2) : desc, combo: combo };
}

// `hyprctl binds -j`
function hyprland(json) {
    const mods = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];
    // binds without a description fall back to the dispatcher name, e.g. HL.Dispatcher(focus) -> focus
    return JSON.parse(json).map(b => row(b.description || b.dispatcher.replace(/^HL\.Dispatcher\((.*)\)$/, "$1"),
        mods.filter(m => b.modmask & m[0]).map(m => m[1]), b.key, keyName(b.key)));
}

// mango/conf/binds*.conf: bind[flags]=MODS,key,action,args, axisbind=MODS,direction,action,
// mousebind=MODS,button,action,args, gesturebind=MODS,direction,fingers,action
function mango(text) {
    const out = [];
    let desc = "";
    for (const raw of text.split("\n")) {
        const line = raw.trim();
        if (line.startsWith("#")) { desc = line.replace(/^#+\s*/, ""); continue; }
        const m = /^(bind[a-z]*|axisbind|mousebind|gesturebind)\s*=\s*(.*)$/.exec(line);
        if (!m) { desc = ""; continue; }
        const f = m[2].split(",").map(s => s.trim());
        const mods = f[0].toUpperCase().split("+").filter(s => s !== "NONE");
        const gesture = m[1] === "gesturebind";
        const shown = m[1] === "axisbind" ? "Wheel " + (arrows[f[1].toLowerCase()] ?? f[1])
            : gesture ? f[2] + " fingers " + (arrows[f[1].toLowerCase()] ?? f[1]) : keyName(f[1]);
        out.push(row(desc || f[gesture ? 3 : 2], mods, f[1], shown));
        desc = "";
    }
    return out;
}
