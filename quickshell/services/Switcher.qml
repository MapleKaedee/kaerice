pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// Alt+Tab switcher and overview state: window list, selection, focus on commit.
// Switcher lists windows most-recently-used first; overview lists them by workspace, left to right.
Singleton {
    id: root
    property bool open: false
    property int index: 0
    property string mode: "switcher" // or "overview"

    // lastIpcObject (focusHistoryID 0 = focused now, at = position) is only fresh after refreshToplevels(), called on open
    readonly property var windows: Hyprland.toplevels.values
        .filter(t => t.wayland)
        .sort(root.mode === "overview"
            ? (a, b) => (a.workspace?.id ?? 0) - (b.workspace?.id ?? 0) || (a.lastIpcObject.at?.[0] ?? 0) - (b.lastIpcObject.at?.[0] ?? 0)
            : (a, b) => (a.lastIpcObject.focusHistoryID ?? 999) - (b.lastIpcObject.focusHistoryID ?? 999))

    // first press opens on the previous window (+1) or the last one (-1)
    function step(delta) {
        if (!root.open) {
            Hyprland.refreshToplevels();
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
        if (w) w.wayland.activate();
    }

    function cancel() { root.open = false; }

    // overview starts on the focused window; a second toggle closes it
    function toggleOverview() {
        if (root.open && root.mode === "overview") { root.open = false; return; }
        Hyprland.refreshToplevels();
        root.mode = "overview";
        root.index = Math.max(0, root.windows.findIndex(t => t.wayland.activated));
        root.open = true;
    }
}
