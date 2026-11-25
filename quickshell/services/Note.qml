pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Temp note text. Saved to a state file 0.5 s after the last change (and on close),
// so it survives reloads, restarts and logins until cleared.
Singleton {
    id: root
    property string text: saved.text()

    onTextChanged: timer.restart()
    function flush() { timer.stop(); saved.setText(root.text); }
    function copy() { copier.text = root.text; copier.running = true; }

    Timer { id: timer; interval: 500; onTriggered: root.flush() }
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
