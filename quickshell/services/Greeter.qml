pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick
import "GreeterState.js" as State

// Login for greeter.qml, which greetd runs as the user "greeter": it cannot read the home of who logs in.
Singleton {
    id: root
    readonly property var user: State.users(passwd.text())[0] ?? null
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null
    property bool busy: false
    property string error: ""
    property string prompt: ""     // a question after the password (a code); "" means the password
    property string password: ""   // held only until greetd asks for it

    function nextSession(step) {
        if (sessions.length) sessionIndex = (sessionIndex + step + sessions.length) % sessions.length;
    }

    // Never cancelSession(): PAM counts a conversation cut short as a failed login (faillock).
    function login(text) {
        if (busy || text === "" || !user || !session) return;
        error = "";
        busy = true;
        if (prompt !== "") { prompt = ""; Greetd.respond(text); return; }
        password = text;
        Greetd.createSession(user.user);
    }

    function reset(message) { busy = false; prompt = ""; password = ""; error = message; }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) root.error = message;
            if (!responseRequired) return;
            if (root.password !== "") { Greetd.respond(root.password); root.password = ""; }
            else { root.busy = false; root.prompt = message; }
        }
        function onAuthFailure(message) { root.reset(message || "Wrong password"); }
        function onError(error) { root.reset(error); }
        function onReadyToLaunch() {
            saved.setText(root.session.file);
            const r = State.launch(root.session);
            Greetd.launch(r.command, r.environment, true);
        }
    }

    FileView { id: passwd; path: "/etc/passwd"; blockLoading: true }
    FileView { id: saved; path: Quickshell.statePath("last-session"); blockLoading: true; printErrors: false }

    Process {
        running: true
        command: ["sh", "-c", "grep -H -E '^(Name|Exec|DesktopNames|NoDisplay|Hidden)=' /usr/share/wayland-sessions/*.desktop"]
        stdout: StdioCollector {
            id: listing
            onStreamFinished: {
                root.sessions = State.sessions(listing.text);
                root.sessionIndex = State.pick(root.sessions, saved.text().trim());
            }
        }
    }
}
