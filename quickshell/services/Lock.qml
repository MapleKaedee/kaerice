pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

// Session lock state + PAM unlock. The lock surface itself is components/lock/LockScreen.qml.
// `locked` is saved to the state dir and read back synchronously, so a reload or a crash-restart stays locked.
Singleton {
    id: root
    property bool locked: saved.text().trim() === "1"
    property bool secure: false      // compositor confirmed the lock (set by LockScreen)
    property bool busy: false        // PAM check running
    property string error: ""        // shown under the password field
    property string password: ""     // held only until PAM asks for it

    function lock() { root.error = ""; root.locked = true; }

    function unlock(pass) {
        if (root.busy || pass === "") return;
        root.password = pass;
        root.error = "";
        root.busy = true;
        if (!pam.start()) { root.busy = false; root.password = ""; root.error = "PAM did not start"; }
    }

    onLockedChanged: saved.setText(locked ? "1" : "0")

    FileView {
        id: saved
        path: Quickshell.statePath("locked")
        blockLoading: true
        printErrors: false
    }

    // default config "login" (pam_unix + faillock: 3 failures lock the account for 10 min)
    PamContext {
        id: pam
        onResponseRequiredChanged: if (responseRequired) { respond(root.password); root.password = ""; }
        onMessageChanged: if (messageIsError && message) root.error = message // e.g. faillock "account is locked"
        onCompleted: result => {
            root.busy = false;
            root.password = "";
            if (result === PamResult.Success) root.locked = false;
            else if (!root.error) root.error = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
        }
        onError: err => { root.busy = false; root.password = ""; root.error = PamError.toString(err); }
    }

    // logind is about to sleep (lid, power menu, idle suspend): lock first
    Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => { if (line.includes("PrepareForSleep (true")) root.lock(); }
        }
    }

    // sleep delay lock, held while not securely locked: suspend waits (max 5 s) until the lock surface is up
    Process {
        running: !root.secure
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=kaerice",
                  "--why=Lock the screen before sleep", "sleep", "infinity"]
    }
}
