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

    Socket {
        id: socket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/kaerice/kaericed.sock"
        connected: true
        parser: SplitParser {
            onRead: line => {
                const topics = State.merge(root.topics, line);
                if (topics) root.topics = topics;
                else console.warn("kaericed sent a line that is not an object");
            }
        }
        onConnectionStateChanged: if (connected) { root.tries = 0; root.down = false; }
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
