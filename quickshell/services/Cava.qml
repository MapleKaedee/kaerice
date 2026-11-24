pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Audio spectrum from cava (config/cava.conf: 64 bars, values 0..100).
// cava runs only while a media player is playing; bars is empty otherwise.
Singleton {
    id: root
    readonly property bool active: Media.playing
    property var bars: []

    onActiveChanged: if (!active) root.bars = []

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellDir + "/config/cava.conf"]
        stdout: SplitParser {
            onRead: line => root.bars = line.split(";").filter(v => v !== "").map(Number)
        }
    }
}
