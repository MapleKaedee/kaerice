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

    Timer { id: timer; interval: 500; onTriggered: root.flush() }
    FileView { id: saved; path: Quickshell.statePath("note"); blockLoading: true; printErrors: false }
}
