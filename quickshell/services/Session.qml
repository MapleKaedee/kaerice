pragma Singleton

import Quickshell
import QtQuick
import "SessionState.js" as State

// Reasons to think twice before logout / reboot / shutdown: a package manager running (or the pacman lock),
// downloads in progress, or no way to find out. Kept up to date while the power menu is open.
Singleton {
    id: root
    property var warnings: []

    function check() {
        late.restart();
        Backend.call("session.check", {}, (code, data) => {
            late.stop();
            root.warnings = State.warnings(code, data);
        });
    }

    // more than once: a package manager can start, or take its lock, after the menu opened
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: Ui.power
        onTriggered: root.check()
        onRunningChanged: if (running) root.warnings = [];
    }

    // a daemon that hangs must not look like "nothing is running"
    Timer { id: late; interval: 1000; onTriggered: root.warnings = State.warnings("Timeout") }
}
