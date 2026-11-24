pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screen backlight via brightnessctl (its default device). percent is -1 until the first read.
// shortcut: sysfs backlight gives no reliable change events, so it polls every 2 s; set() updates instantly.
Singleton {
    id: root
    property int percent: -1

    // never below 1% so the screen can't go black
    function set(p) {
        if (root.percent < 0) return;
        root.percent = Math.max(1, Math.min(100, Math.round(p)));
        Quickshell.execDetached(["brightnessctl", "-q", "set", root.percent + "%"]);
    }
    function step(delta) { set(root.percent + delta); }

    Process {
        id: read
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: out
            // -m prints one line: device,class,current,percent%,max
            onStreamFinished: {
                const p = parseInt(out.text.split(",")[3]);
                if (!isNaN(p)) root.percent = p;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: read.running = true
    }
}
