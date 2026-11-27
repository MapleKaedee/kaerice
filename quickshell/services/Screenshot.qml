pragma Singleton

import Quickshell
import QtQuick

// Screenshot flow: scripts/screenshot.sh captures to a temp file and calls `screenshot edit <file>`;
// the editor then saves (to ~/Pictures/Screenshots, + clipboard), copies only, or discards.
// Exactly one file is kept per screenshot, edited or not; temp files are always removed.
Singleton {
    id: root
    readonly property string script: Quickshell.shellDir + "/scripts/screenshot.sh"
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string editing: "" // temp capture open in the editor; "" = closed
    property bool hidden: false // screenshot.sh hides the editor while it captures, or it would be in the shot
    signal finishRequested(bool save) // IPC save/copy: the editor exports, then calls finish()

    function take(mode) { Quickshell.execDetached([root.script, mode]); }

    function edit(file) {
        if (root.editing) discard(); // a new capture replaces an unfinished one
        root.hidden = false;
        root.editing = file;
    }

    // rendered: the editor's export (temp). save: keep it in dir and copy; otherwise copy only.
    function finish(rendered, save) {
        const out = root.dir + "/" + root.editing.split("/").pop();
        Quickshell.execDetached(["sh", "-c", `
            src=$1 shot=$2 out=$3 save=$4
            if [ "$save" = 1 ]; then
                mkdir -p "\${out%/*}" && cp "$src" "$out" && notify-send -a Screenshot -i "$out" "Screenshot saved" "$out"
            fi
            wl-copy --type image/png < "$src"
            rm -f "$src" "$shot"`, "sh", rendered, root.editing, out, save ? "1" : "0"]);
        root.editing = "";
    }

    function discard() {
        Quickshell.execDetached(["rm", "-f", root.editing]);
        root.editing = "";
    }
}
