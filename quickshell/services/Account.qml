pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The user's real name and avatar, kept by AccountsService (shared with the greeter). Passwords are not handled here:
// changePassword() opens `passwd` in a terminal.
Singleton {
    id: root
    readonly property string user: Quickshell.env("USER")
    readonly property string name: realName || user
    readonly property string avatar: "/var/lib/AccountsService/icons/" + user
    property string realName: ""
    property int revision: 0     // bumped when the avatar changes, so images reload
    property string error: ""
    property string picked: ""   // image chosen for the avatar; the Users page crops it, then calls setAvatar()

    readonly property string service: "org.freedesktop.Accounts"
    property string path: ""     // /org/freedesktop/Accounts/User<uid>

    function refresh() { reader.running = true; }
    function setName(n) { call("SetRealName", n.replace(/[\x00-\x1f\x7f:]/g, "").trim()); }
    function setAvatar(file) { call("SetIconFile", file); }
    function call(method, arg) {
        if (!root.path || writer.running) return;
        root.error = "";
        writer.method = method;
        writer.command = ["busctl", "--system", "call", "--", root.service, root.path, root.service + ".User", method, "s", arg];
        writer.running = true;
    }

    // the picker is a normal window, below overlays: the settings overlay closes meanwhile
    function pickAvatar() { root.error = ""; Ui.settings = false; picker.running = true; }
    function changePassword() { Ui.settings = false; Quickshell.execDetached(["kitty", "--title", "Change password", "--hold", "passwd"]); }

    Component.onCompleted: refresh()

    Process {
        id: reader
        command: ["sh", "-c", "p=/org/freedesktop/Accounts/User$(id -u); echo $p; busctl --system --json=short get-property org.freedesktop.Accounts $p org.freedesktop.Accounts.User RealName"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                const lines = out.text.trim().split("\n");
                root.path = lines[0];
                try { root.realName = JSON.parse(lines[1]).data; } catch (e) { root.realName = ""; }
            }
        }
    }

    Process {
        id: writer
        property string method
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code !== 0) root.error = err.text.trim() || "AccountsService did not accept the change";
            else if (method === "SetIconFile") root.revision++;
            else root.refresh();
        }
    }

    Process {
        id: picker
        command: ["sh", "-c", "exec zenity --file-selection --title='Choose an avatar' --file-filter='Images | *.png *.jpg *.jpeg *.webp'"]
        stdout: StdioCollector { id: choice }
        onExited: code => {
            if (code === 127) root.error = "zenity is not installed";
            if (code === 0) root.picked = choice.text.trim();
            Ui.settings = true;
        }
    }
}
