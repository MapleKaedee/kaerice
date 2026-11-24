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
    property var entries: []       // [{ line, id, text }] newest first

    function refresh() { lister.running = true; }

    // the full "id<TAB>preview" line is what cliphist decode/delete expect on stdin
    function copy(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", e.line]);
    }

    function remove(e) {
        if (!e || del.running) return;
        del.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", e.line];
        del.running = true;
    }

    function wipe() { wiper.running = true; }

    // records every clipboard change
    Process {
        running: true
        command: ["wl-paste", "--watch", "cliphist", "store"]
    }

    Process {
        id: lister
        command: ["sh", "-c", "exec cliphist list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.entries = listOut.text.split("\n").filter(l => l).map(l => {
                const tab = l.indexOf("\t");
                return { line: l, id: l.slice(0, tab), text: l.slice(tab + 1) };
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
