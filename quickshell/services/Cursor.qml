pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Cursor theme and size of every app, through kaericed: it copies the theme in that one size and makes the copy the
// theme "default".
// set() updates theme and size at once; one write runs at a time and the latest wins, like in Brightness.
Singleton {
    id: root
    property var state: null      // { themes, theme, size }, null while unknown
    property var wanted: null     // { theme, size } being written
    property bool writing: false
    property bool failed: false
    readonly property var themes: state?.themes ?? []
    readonly property string theme: (wanted ?? state)?.theme ?? ""
    readonly property int size: (wanted ?? state)?.size ?? 0
    readonly property bool installing: picker.running || installer.running

    function refresh() {
        root.failed = false;
        Backend.call("cursor.read", {}, (code, data) => root.state = code === "" ? data : null);
    }

    function set(theme, size) {
        root.wanted = { theme: theme, size: size };
        if (!root.writing) write();
    }
    function write() {
        const w = root.wanted;
        root.writing = true;
        Backend.call("cursor.set", w, (code, name) => {
            root.writing = false;
            if (root.wanted !== w) { write(); return; }
            root.failed = code !== "";
            if (code === "") {
                root.state = Object.assign({}, root.state, w);
                show(name, w.size);
            }
            root.wanted = null;
        });
    }

    // the picker is a normal window, below overlays: the settings overlay closes meanwhile
    function install() { Ui.settings = false; picker.running = true; }
    function notify(title, text) { Quickshell.execDetached(["notify-send", "-a", "kaerice", "--", title, text]); }

    Process {
        id: picker
        command: ["sh", "-c", `exec zenity --file-selection --title='Choose a cursor theme' \
            --file-filter='Cursor themes | *.zip *.7z *.rar *.cab *.tar *.tar.* *.tgz *.txz *.exe *.deskthemepack *.themepack *.cur *.ani' \
            --file-filter='All files | *'`]
        stdout: StdioCollector { id: choice }
        onExited: code => {
            Ui.settings = true;
            if (code === 127) root.notify("Cursor not installed", "zenity is not installed");
            if (code !== 0) return;
            installer.path = choice.text.replace(/\n$/, "");
            installer.running = true;
        }
    }
    Process {
        id: installer
        property string path
        // setsid: a reload of the shell must not stop it halfway
        command: ["setsid", "-fw", Quickshell.shellDir + "/scripts/install-cursor.sh", path]
        stdout: StdioCollector { id: added }
        stderr: StdioCollector { id: notes }
        onExited: code => {
            root.notify(code === 0 ? "Cursor installed" : "Cursor not installed", (added.text + notes.text).trim());
            root.refresh();
        }
    }

    // X11 windows without a cursor of their own show the root's: Hyprland sets that one only when Xwayland starts
    function show(copy, size) {
        Quickshell.execDetached(["sh", "-c", `hyprctl setcursor "$1" "$2"
            pgrep -x Xwayland && command -v xsetroot && exec xsetroot -cursor_name left_ptr`, "sh", copy, String(size)]);
    }
}
