pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screen backlight via brightnessctl (its default device). percent is -1 until the first read.
// set() updates percent at once; writes run one brightnessctl at a time, and presses that arrive
// during a write coalesce into one follow-up write of the latest value, so fast key repeats stay in order.
// shortcut: sysfs backlight gives no reliable change events, so it polls every 2 s.
Singleton {
    id: root
    property int percent: -1
    property int gen: 0          // bumps on every set(); a read started before it is stale
    property bool dirty: false   // a newer value is waiting for the current write to finish

    // never below 1% so the screen can't go black
    function set(p) {
        if (root.percent < 0) return;
        root.percent = Math.max(1, Math.min(100, Math.round(p)));
        root.gen++;
        if (writer.running) root.dirty = true;
        else root.write();
    }
    function step(delta) { set(root.percent + delta); }

    // idle dim: remember the level, drop to 10%; undim restores it
    property int undimTo: -1
    function dim() { if (root.percent < 0 || root.undimTo >= 0) return; root.undimTo = root.percent; set(Math.min(root.percent, 10)); }
    function undim() { if (root.undimTo < 0) return; set(root.undimTo); root.undimTo = -1; }

    function write() {
        root.dirty = false;
        writer.command = ["brightnessctl", "-q", "set", root.percent + "%"];
        writer.running = true;
    }

    Process {
        id: writer
        // callLater: restart only after this run has fully stopped
        onExited: if (root.dirty) Qt.callLater(root.write)
    }

    Process {
        id: read
        property int gen: 0
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: out
            // -m prints one line: device,class,current,percent%,max
            onStreamFinished: {
                if (read.gen !== root.gen || writer.running || root.dirty) return; // a set() happened meanwhile
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
        onTriggered: { read.gen = root.gen; read.running = true; }
    }
}
