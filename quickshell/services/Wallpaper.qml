pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Current wallpaper (saved in Quickshell's state dir, restored on start)
// and the images in the repo's wallpapers/ folder.
// shellDir is the quickshell/ symlink, so ".." is the repo.
Singleton {
    id: root
    readonly property string dir: Quickshell.shellDir + "/../wallpapers"
    readonly property string fallback: dir + "/wallhaven-gwq1w3_1920x1080.png"
    property string source: ""
    property var images: []        // canonical paths, sorted

    function apply(path) {
        const p = path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
        root.source = p;
        saved.setText(p);
    }

    // shortcut: "current wallpaper" is matched by file name, since saved paths may be canonical or go through the symlink
    function base(p) { return p.split("/").pop(); }

    // re-lists the folder, so newly added images show up
    function scan() { scanner.running = true; }

    FileView {
        id: saved
        path: Quickshell.statePath("wallpaper")
        onLoaded: root.source = text().trim() || root.fallback
        onLoadFailed: root.source = root.fallback
    }

    Process {
        id: scanner
        command: ["find", "-L", root.dir + "/", "-maxdepth", "1", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")",
                  "-exec", "realpath", "{}", "+"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: root.images = scanOut.text.split("\n").filter(l => l).sort()
        }
    }
}
