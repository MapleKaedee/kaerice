pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Temp note text in a state file: survives reloads, restarts and logins until cleared.
// Saved at every change, not after a pause: a Singleton's onDestruction runs neither on a reload nor on exit.
Singleton {
    id: root
    property string text: saved.text()

    onTextChanged: saved.setText(root.text)
    function copy() { copier.text = root.text; copier.running = true; }

    FileView { id: saved; path: Quickshell.statePath("note"); blockLoading: true; printErrors: false }
    Process { // through stdin: everyone can read the arguments of a process
        id: copier
        property string text
        property string written
        command: ["wl-copy", "--type", "text/plain"] // or a note that looks like SVG is offered as an image
        stdinEnabled: true
        onStarted: { written = text; write(written); stdinEnabled = false; }
        onExited: { stdinEnabled = true; if (written !== text) running = true; } // copied again while writing
    }
}
