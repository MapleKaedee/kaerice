pragma Singleton

import Quickshell
import QtQuick

// Which overlay or panel is open. Set by keybinds (ipc/), bar cards and the overlays themselves.
Singleton {
    property bool launcher: false
    property bool power: false
    property bool wifi: false
    property bool notifications: false
    property bool clipboard: false
    property bool wallpaperPicker: false
}
