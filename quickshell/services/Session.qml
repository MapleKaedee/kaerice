pragma Singleton

import Quickshell
import QtQuick
import "SessionState.js" as State

// Reasons to think twice before logout / reboot / shutdown: a package manager running (or the pacman lock),
// downloads in progress, or no way to find out. The power menu calls refresh() when it opens.
Singleton {
    id: root
    property var warnings: []

    function refresh() {
        root.warnings = [];
        late.restart();
        Backend.call("session.check", {}, (code, data) => {
            late.stop();
            root.warnings = State.warnings(code, data);
        });
    }

    // a daemon that hangs must not look like "nothing is running"
    Timer { id: late; interval: 1000; onTriggered: root.warnings = State.warnings("Timeout") }
}
