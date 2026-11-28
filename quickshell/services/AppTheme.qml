pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Light/dark preference for apps: GTK color-scheme (libadwaita, and Firefox/Chromium/Electron through the
// gtk portal) plus the matching adw-gtk3 theme for GTK3. The kaerice shell itself keeps its own Theme.
// gsettings (dconf) stores the choice, so it persists and is shared with every session; no state file.
Singleton {
    id: root
    property bool dark: true

    function setDark(d) {
        root.dark = d;
        Quickshell.execDetached(["sh", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme \"$1\"; gsettings set org.gnome.desktop.interface gtk-theme \"$2\"",
            "sh", d ? "prefer-dark" : "default", d ? "adw-gtk3-dark" : "adw-gtk3"]);
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { id: out; onStreamFinished: root.dark = out.text.includes("dark") }
    }
}
