.pragma library

// Setting "bar.cards": card ids in order, "|" between left, center and right. Cards not in it are hidden.
// Pure, so tests/tst_bar.qml can check it.
const defaults = "workspaces title | media | privacy tray network volume brightness battery notifications control clock";
const sections = ["left", "center", "right"];
const ids = tokens(defaults).filter(t => t !== "|");

function tokens(text) { return text.split(/(\|)|\s+/).filter(t => t); }

function valid(text) {
    if (typeof text !== "string") return false;
    const t = tokens(text), cards = t.filter(x => x !== "|");
    return t.length - cards.length === 2 && cards.every((c, i) => ids.includes(c) && cards.indexOf(c) === i);
}

// { left: [id], center: [id], right: [id] }
function parse(text) {
    const out = {}, parts = text.split("|");
    sections.forEach((s, i) => out[s] = tokens(parts[i]));
    return out;
}

function hidden(text) { const t = tokens(text); return ids.filter(i => !t.includes(i)); }

// "" = hidden
function section(text, id) { const p = parse(text); return sections.find(s => p[s].includes(id)) ?? ""; }

// by: -1 earlier, 1 later. Past the end of a section it goes into the next one.
function canMove(text, id, by) {
    const t = tokens(text), i = t.indexOf(id);
    return i >= 0 && i + by >= 0 && i + by < t.length;
}
function move(text, id, by) {
    if (!canMove(text, id, by)) return text;
    const t = tokens(text), i = t.indexOf(id);
    t[i] = t[i + by];
    t[i + by] = id;
    return t.join(" ");
}

// hides a card, or puts it back at the end of its default section
function toggle(text, id) {
    const p = parse(text), s = section(text, id);
    if (s) p[s] = p[s].filter(c => c !== id);
    else p[section(defaults, id)].push(id);
    return sections.map(n => p[n].join(" ")).join(" | ");
}

// a chosen monitor that is not connected means every monitor, so the bar never disappears
function screens(all, name) {
    const found = all.filter(s => s.name === name);
    return found.length ? found : all;
}
