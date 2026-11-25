pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history backed by cliphist. Recording runs while this shell runs.
// cliphist skips content that password managers mark as sensitive,
// but anything else you copy is stored on disk (~/.cache/cliphist/db) until removed.
Singleton {
    id: root
    property bool available: true  // false when cliphist is not installed
    property var entries: []       // [{ id, text }] newest first

    function refresh() { lister.running = true; }

    // only the id: everyone can read the arguments of a process
    function copy(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", e.id]);
    }

    function remove(e) {
        if (!e || del.running) return;
        del.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", e.id];
        del.running = true;
    }

    function wipe() { wiper.running = true; }

    // records every clipboard change; pdeathsig: a killed shell must not leave it behind
    Process {
        id: recorder
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--watch", "cliphist", "store"]
        onExited: code => { if (code !== 127) again.start(); } // 127: wl-paste is not installed
    }
    Timer { id: again; interval: 10000; onTriggered: recorder.running = true }

    Process {
        id: lister
        command: ["sh", "-c", "exec cliphist list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.entries = listOut.text.split("\n").filter(l => l).map(l => {
                const tab = l.indexOf("\t");
                return { id: l.slice(0, tab), text: l.slice(tab + 1) };
            })
        }
        onExited: code => root.available = code !== 127
    }

    Process {
        id: del
        onExited: root.refresh()
    }

    Process {
        id: wiper
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
}
