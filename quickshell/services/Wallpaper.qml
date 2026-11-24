pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Current wallpaper (saved in Quickshell's state dir, restored on start) and the images to choose from:
// the repo's wallpapers/ folder and ~/Pictures/Wallpapers (downloads from Wallhaven).
// shellDir is the quickshell/ symlink, so ".." is the repo.
Singleton {
    id: root
    readonly property string dir: Quickshell.shellDir + "/../wallpapers"
    readonly property string downloads: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string fallback: dir + "/wallhaven-gwq1w3_1920x1080.png"
    property string source: ""
    property var images: []        // canonical paths, sorted
    property string error: ""

    function apply(path) {
        const p = path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
        root.source = p;
        saved.setText(p);
    }

    // shortcut: "current wallpaper" is matched by file name, since saved paths may be canonical or go through the symlink
    function base(p) { return p.split("/").pop(); }
    function isCurrent(path) { return base(path) === base(source); }

    // re-lists the folders, so newly added images show up
    function scan() { scanner.running = true; }

    // to the Trash. The fallback stays: it is what the shell shows when nothing else is left.
    function canRemove(path) { return base(path) !== base(fallback); }
    function remove(path) {
        if (!canRemove(path) || trash.running) return;
        error = "";
        trash.path = path;
        trash.running = true;
    }

    FileView {
        id: saved
        path: Quickshell.statePath("wallpaper")
        onLoaded: root.source = text().trim() || root.fallback
        onLoadFailed: root.source = root.fallback
    }

    Process {
        id: scanner
        // a folder that does not exist yet is fine
        command: ["find", "-L", root.dir + "/", root.downloads + "/", "-maxdepth", "1", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")",
                  "-exec", "realpath", "{}", "+"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                const found = scanOut.text.split("\n").filter(l => l).sort();
                if (found.join("\n") !== root.images.join("\n")) root.images = found; // a new list scrolls the views back to the top
            }
        }
    }

    Process {
        id: trash
        property string path
        command: ["gio", "trash", "--", path]
        onExited: code => {
            if (code !== 0) { root.error = root.base(path) + " could not be moved to the Trash."; return; }
            if (root.isCurrent(path)) root.apply(root.fallback);
            root.scan();
        }
    }
}
