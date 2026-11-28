pragma Singleton

import Quickshell
import Quickshell.Wayland
import QtQuick

// Alt+Tab switcher and overview state: window list, selection, focus on commit.
// Switcher lists windows most-recently-used first; overview lists them by workspace, left to right.
Singleton {
    id: root
    property bool open: false
    property int index: 0
    property string mode: "switcher" // or "overview"

    // focus order, most recent first. Compositors do not share theirs, so it starts with the shell.
    property var recent: []
    readonly property var active: ToplevelManager.activeToplevel
    onActiveChanged: remember()
    Component.onCompleted: remember()
    function remember() {
        const all = ToplevelManager.toplevels.values;
        if (root.active) root.recent = [root.active].concat(root.recent.filter(t => t !== root.active && all.includes(t)));
    }

    // empty while closed: no sorting on every focus or title change
    readonly property var windows: {
        if (!root.open) return [];
        const all = ToplevelManager.toplevels.values;
        const rank = t => { const i = root.recent.indexOf(t); return i < 0 ? root.recent.length + all.indexOf(t) : i; };
        if (root.mode !== "overview") return all.filter(t => t).sort((a, b) => rank(a) - rank(b));
        const place = new Map(all.map(t => [t, Compositor.place(t)]));
        return all.filter(t => t).sort((a, b) => {
            const pa = place.get(a), pb = place.get(b);
            if (!pa || !pb) return !pa - !pb || all.indexOf(a) - all.indexOf(b);
            return pa.order - pb.order || pa.x - pb.x || all.indexOf(a) - all.indexOf(b);
        });
    }

    // first press opens on the previous window (+1) or the last one (-1)
    function step(delta) {
        if (!root.open) {
            Compositor.refreshPlacement();
            root.mode = "switcher";
            root.index = 0;
            root.open = true;
        }
        const n = root.windows.length;
        if (n === 0) { root.open = false; return; }
        root.index = (root.index + delta + n) % n;
    }

    function commit() {
        if (!root.open) return;
        const w = root.windows[root.index];
        root.open = false;
        if (w) Compositor.activate(w);
    }

    // Alt let go: the overview stays open
    function released() { if (root.mode === "switcher") root.commit(); }

    function cancel() { root.open = false; }

    // overview starts on the focused window; a second toggle closes it
    function toggleOverview() {
        if (root.open && root.mode === "overview") { root.open = false; return; }
        Compositor.refreshPlacement();
        root.mode = "overview";
        root.open = true;
        root.index = Math.max(0, root.windows.findIndex(t => t.activated));
    }
}
