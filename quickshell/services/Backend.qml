pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "BackendState.js" as State

// Connection to kaericed (core/).
Singleton {
    id: root
    property var topics: ({})   // topic -> its last state
    property bool down: false
    property int tries: 0
    property int lastId: 0
    property var pending: ({})   // id of a call -> { done, until }
    property int waiting: 0      // entries in pending, which sends no change signal

    // done(code, data) runs once; code is "" when the call succeeded
    function call(name, args, done) {
        if (!socket.connected) { done("Disconnected"); return; }
        // past the daemon's own limit (60 s for Wi-Fi, 5 s for the rest), for a daemon that accepts but never answers
        root.pending[++root.lastId] = { done: done, until: Date.now() + (name.startsWith("wifi.") ? 65000 : 10000) };
        root.waiting++;
        socket.write(JSON.stringify({ id: root.lastId, call: name, args: args }) + "\n");
        socket.flush();
    }

    function answer(id, code, data) {
        const p = root.pending[id];
        if (!p) return;
        delete root.pending[id];
        root.waiting--;
        p.done(code, data);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.waiting > 0
        onTriggered: Object.keys(root.pending).forEach(id => { if (root.pending[id].until <= Date.now()) root.answer(id, "Timeout"); })
    }

    Socket {
        id: socket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/kaerice/kaericed.sock"
        connected: true
        parser: SplitParser {
            onRead: line => {
                const message = State.parse(line);
                if (!message) console.warn("kaericed sent a line that is not an object");
                else if (State.isAnswer(message)) root.answer(message.id, State.code(message), message.data);
                else root.topics = State.merge(root.topics, message);
            }
        }
        onConnectionStateChanged: {
            if (connected) { root.tries = 0; root.down = false; }
            else {
                Object.keys(root.pending).forEach(id => root.answer(id, "Disconnected"));
                root.topics = State.merge(root.topics, { sleep: null }); // Lock takes over at once, not when down
            }
        }
    }

    // slower after 10 s: the daemon may never come, and each failed try adds a line to the log
    Timer {
        interval: root.tries < 20 ? 500 : 10000
        running: !socket.connected
        repeat: true
        onTriggered: { root.tries++; socket.connected = true; }
    }

    // longer than one restart of the daemon (RestartSec) and one try
    Timer {
        interval: 2000
        running: !socket.connected
        onTriggered: { root.down = true; root.topics = {}; }
    }
}
