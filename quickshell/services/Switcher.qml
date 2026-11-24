pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// Alt+Tab state: windows in most-recently-used order, the selection, focus on commit.
Singleton {
    id: root
    property bool open: false
    property int index: 0

    // focusHistoryID 0 = focused now; lastIpcObject is only fresh after refreshToplevels() (called on open)
    readonly property var windows: Hyprland.toplevels.values
        .filter(t => t.wayland)
        .sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 999) - (b.lastIpcObject.focusHistoryID ?? 999))

    // first press opens on the previous window (+1) or the last one (-1)
    function step(delta) {
        if (!root.open) {
            Hyprland.refreshToplevels();
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
}
