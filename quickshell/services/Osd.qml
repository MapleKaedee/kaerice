pragma Singleton

import Quickshell
import QtQuick

// Which level the OSD shows, and for how long. show() restarts the hide timer.
Singleton {
    id: root
    property string kind: ""     // "volume" | "brightness"
    property bool shown: false
    property int timeout: 1500   // ms after the last change

    function show(k) {
        root.kind = k;
        root.shown = true;
        hide.restart();
    }

    Timer { id: hide; interval: root.timeout; onTriggered: root.shown = false }
}
