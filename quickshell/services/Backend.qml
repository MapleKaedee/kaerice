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
    property var pending: ({})   // id of a call -> its done

    // done(code, data) runs once; code is "" when the call succeeded
    function call(name, args, done) {
        if (!socket.connected) { done("Disconnected"); return; }
        root.pending[++root.lastId] = done;
        socket.write(JSON.stringify({ id: root.lastId, call: name, args: args }) + "\n");
        socket.flush();
    }

    function answer(id, code, data) {
        const done = root.pending[id];
        delete root.pending[id];
        if (done) done(code, data);
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
            else Object.keys(root.pending).forEach(id => root.answer(id, "Disconnected"));
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
