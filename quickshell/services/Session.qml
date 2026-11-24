pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Reasons to think twice before logout / reboot / shutdown: a package manager running (or the pacman lock),
// or downloads in progress. The power menu calls refresh() when it opens.
Singleton {
    id: root
    property bool packages: false
    property bool downloads: false
    readonly property var warnings: [
        packages ? "A package manager is running: stopping now can break the update." : "",
        downloads ? "Downloads are in progress." : ""
    ].filter(w => w)

    function refresh() {
        root.packages = false;
        root.downloads = false;
        pkg.running = true;
        dl.running = true;
    }

    Process {
        id: pkg
        command: ["sh", "-c", "pidof -q pacman paru yay || [ -e /var/lib/pacman/db.lck ]"]
        onExited: code => root.packages = code === 0
    }
    Process {
        id: dl
        command: ["sh", "-c", "pidof -q curl wget aria2c yt-dlp || ls \"$HOME\"/Downloads/*.part \"$HOME\"/Downloads/*.crdownload >/dev/null 2>&1"]
        onExited: code => root.downloads = code === 0
    }
}
