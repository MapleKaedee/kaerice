pragma Singleton

import Quickshell
import QtQuick

// Copies the theme and the wallpaper for the login screen (greeter.qml), which cannot read $HOME:
// at start and when one of them changes, never while idle.
Singleton {
    readonly property string key: JSON.stringify(["theme.dark", "theme.accent", "theme.radius", "theme.border", "theme.shadow"]
        .map(k => Settings.get(k)).concat(Wallpaper.source))

    function sync() { Quickshell.execDetached([Quickshell.shellDir + "/scripts/greeter-sync.sh", Settings.path, Wallpaper.source]); }

    onKeyChanged: sync()
    Component.onCompleted: sync()
}
