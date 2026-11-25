pragma Singleton

import Quickshell
import QtQuick
import "BrightnessState.js" as State

// Screen backlight, through kaericed. percent is -1 while it is unknown.
// set() updates percent at once; one write runs at a time, and presses that arrive during it coalesce into one
// follow-up write of the latest value, so fast key repeats stay in order.
Singleton {
    id: root
    readonly property var payload: Backend.topics.brightness
    readonly property bool unavailable: Backend.down
    readonly property int percent: wanted >= 0 ? wanted : State.level(payload)
    property int wanted: -1      // being written; topics that arrive meanwhile are older
    property bool writing: false

    function set(p) { if (root.percent >= 0) apply(p); }
    function step(delta) { set(root.percent + delta); }

    function apply(p) {
        root.wanted = State.clamp(p);
        if (!root.writing) write();
    }
    function write() {
        const p = root.wanted;
        root.writing = true;
        Backend.call("brightness.set", { percent: p }, code => {
            root.writing = false;
            if (code === "" && root.wanted !== p) { write(); return; }
            if (code === "" && !root.dimmed) root.undimTo = -1;
            root.wanted = -1;
        });
    }

    // idle dim: remember the level, drop to 10%; undim restores it. undimTo stays until a write succeeds, so that the
    // next topic restores the level when the daemon was gone.
    property int undimTo: -1
    property bool dimmed: false
    function dim() {
        if (root.percent < 0 || root.dimmed) return;
        if (root.undimTo < 0) root.undimTo = root.percent;
        root.dimmed = true;
        apply(Math.min(root.percent, 10));
    }
    function undim() { root.dimmed = false; restore(); }
    function restore() { if (!root.dimmed && root.undimTo >= 0 && State.level(root.payload) >= 0) apply(root.undimTo); }
    onPayloadChanged: if (!root.writing) restore() // a write of its own sends a topic too
}
