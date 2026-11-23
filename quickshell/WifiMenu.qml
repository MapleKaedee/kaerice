import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Wi-Fi menu for iwd. Open: click the network card, or qs -c kaerice ipc call wifi toggle
// State comes from iwd's D-Bus API (busctl JSON); actions run through iwctl.
// shortcut: the passphrase is passed to iwctl as an argument, so it is visible in the process list
// for the few seconds the connect takes; switch to an iwd D-Bus agent if that matters.
Scope {
    id: root
    property bool open: false
    property string device: ""     // interface name for iwctl, e.g. wlan0
    property string station: ""    // D-Bus path of the station (empty while Wi-Fi is off)
    property bool powered: false
    property bool scanning: false
    property string connected: ""  // D-Bus path of the connected network
    property var objects: ({})
    property var networks: []      // [{ path, name, type, known, connected, dbm }]
    property string expanded: ""   // path of the network showing the password field
    property string status: ""

    readonly property string nerd: "JetBrainsMono Nerd Font"
    readonly property color ink: "#1c1c1c"
    readonly property color paper: "#f2f0eb"
    readonly property color accent: "#e8335a"

    function refresh() { objs.running = true; }

    function scan() {
        if (!root.station) return;
        Quickshell.execDetached(["busctl", "--system", "call", "net.connman.iwd", root.station, "net.connman.iwd.Station", "Scan"]);
        root.scanning = true;
    }

    function act(args, doing) {
        if (action.running) return;
        root.status = doing;
        action.command = ["iwctl"].concat(args);
        action.running = true;
    }

    function connect(n, pass) {
        root.expanded = "";
        act(pass ? ["--passphrase", pass, "station", root.device, "connect", n.name]
                 : ["station", root.device, "connect", n.name], "Connecting to " + n.name + "…");
    }

    function pick(n) {
        if (n.connected || action.running) return;
        if (n.known || n.type === "open") root.connect(n, "");
        else if (n.type === "psk") root.expanded = root.expanded === n.path ? "" : n.path;
        else root.status = "Enterprise (802.1X) network: set it up once with iwctl";
    }

    // 4-step signal level from dBm
    function bars(dbm) { return dbm >= -55 ? 4 : dbm >= -67 ? 3 : dbm >= -75 ? 2 : 1; }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.open = !root.open; }
    }

    Process {
        id: objs
        command: ["busctl", "--system", "--json=short", "call", "net.connman.iwd", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            id: objsOut
            onStreamFinished: {
                let o;
                try { o = JSON.parse(objsOut.text).data[0]; } catch (e) { return; }
                root.objects = o;
                const dp = Object.keys(o).find(p => o[p]["net.connman.iwd.Device"]);
                if (!dp) { root.device = ""; root.station = ""; root.networks = []; return; }
                const d = o[dp]["net.connman.iwd.Device"];
                const s = o[dp]["net.connman.iwd.Station"];
                root.device = d.Name.data;
                root.powered = d.Powered.data;
                root.station = s ? dp : "";
                root.scanning = s ? s.Scanning.data : false;
                root.connected = s && s.ConnectedNetwork ? s.ConnectedNetwork.data : "";
                if (s) ordered.running = true;
                else root.networks = [];
            }
        }
    }

    Process {
        id: ordered
        command: ["busctl", "--system", "--json=short", "call", "net.connman.iwd", root.station, "net.connman.iwd.Station", "GetOrderedNetworks"]
        stdout: StdioCollector {
            id: orderedOut
            onStreamFinished: {
                let list;
                try { list = JSON.parse(orderedOut.text).data[0]; } catch (e) { return; }
                root.networks = list.map(e => {
                    const n = root.objects[e[0]] ? root.objects[e[0]]["net.connman.iwd.Network"] : null;
                    return n ? {
                        path: e[0],
                        name: n.Name.data,
                        type: n.Type.data,
                        known: !!n.KnownNetwork,
                        connected: e[0] === root.connected,
                        dbm: e[1] / 100
                    } : null;
                }).filter(n => n);
            }
        }
    }

    Process {
        id: action
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            const msg = (actionErr.text || actionOut.text || "").replace(/\x1b\[[0-9;]*m/g, "").trim();
            root.status = code === 0 ? "" : (msg.split("\n").pop() || "Failed");
            root.refresh();
        }
    }

    Timer {
        interval: 3000
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-wifi"

        onVisibleChanged: {
            if (!visible) return;
            root.status = "";
            root.expanded = "";
            keys.forceActiveFocus();
            root.refresh();
            root.scan();
        }

        // click outside the menu closes it
        MouseArea { anchors.fill: parent; onClicked: root.open = false }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.open = false
        }

        Card {
            x: parent.width - width - 14
            y: 60
            width: 380
            height: col.implicitHeight + 24 + offset
            offset: 6

            MouseArea { anchors.fill: parent } // swallow clicks inside the menu

            Column {
                id: col
                x: 12; y: 12
                width: parent.width - 24
                spacing: 10

                // header: title, rescan, power
                Item {
                    width: parent.width
                    height: 36

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wi-Fi" + (root.device ? "  ·  " + root.device : "")
                        color: root.ink
                        font.pixelSize: 18; font.bold: true
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        Card {
                            visible: root.powered
                            width: 38; height: 36; offset: 3
                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(0xf021) // refresh
                                color: root.ink
                                font.family: root.nerd; font.pixelSize: 16
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.scan() }
                        }
                        Card {
                            visible: root.device !== ""
                            width: 38; height: 36; offset: 3
                            fill: root.powered ? root.accent : root.paper
                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(0xf011) // power
                                color: root.powered ? root.paper : root.ink
                                font.family: root.nerd; font.pixelSize: 16
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.act(["device", root.device, "set-property", "Powered", root.powered ? "off" : "on"],
                                                    root.powered ? "Turning Wi-Fi off…" : "Turning Wi-Fi on…")
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.status || (!root.device ? "No Wi-Fi device found"
                                        : !root.powered ? "Wi-Fi is off"
                                        : root.scanning ? "Scanning…" : "")
                    color: root.ink
                    opacity: 0.75
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: list
                    width: parent.width
                    height: Math.min(contentHeight, 7 * 48)
                    visible: count > 0
                    clip: true
                    spacing: 6
                    model: root.networks

                    delegate: Column {
                        id: row
                        required property var modelData
                        readonly property bool isOpen: root.expanded === modelData.path
                        readonly property color fg: modelData.connected ? root.paper : root.ink
                        width: list.width
                        spacing: 6

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: 6
                            color: row.modelData.connected ? root.accent : hover.containsMouse ? "#e4dfd6" : "transparent"
                            border.width: row.modelData.connected || row.isOpen ? 3 : 0
                            border.color: root.ink

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.pick(row.modelData)
                            }

                            Row {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 10

                                // signal: filled bars + faded rest
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "▂▄▆█".slice(0, root.bars(row.modelData.dbm))
                                        color: row.fg
                                        font.family: root.nerd; font.pixelSize: 14
                                    }
                                    Text {
                                        text: "▂▄▆█".slice(root.bars(row.modelData.dbm))
                                        color: row.fg
                                        opacity: 0.25
                                        font.family: root.nerd; font.pixelSize: 14
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 230
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                    color: row.fg
                                    font.pixelSize: 14; font.bold: true
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.modelData.type !== "open"
                                    text: String.fromCodePoint(0xf023) // lock
                                    color: row.fg
                                    font.family: root.nerd; font.pixelSize: 13
                                }
                            }

                            // disconnect button on the connected network
                            Text {
                                visible: row.modelData.connected
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: String.fromCodePoint(0xf00d) // x
                                color: row.fg
                                font.family: root.nerd; font.pixelSize: 16
                                MouseArea {
                                    anchors { fill: parent; margins: -8 }
                                    onClicked: root.act(["station", root.device, "disconnect"], "Disconnecting…")
                                }
                            }
                        }

                        // password field for a new secured network
                        Card {
                            visible: row.isOpen
                            width: parent.width
                            height: 44
                            offset: 3

                            TextInput {
                                id: pass
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: root.ink
                                font.pixelSize: 14
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                Keys.onReturnPressed: if (text) root.connect(row.modelData, text)
                                Keys.onEnterPressed: if (text) root.connect(row.modelData, text)
                                Keys.onEscapePressed: { root.expanded = ""; keys.forceActiveFocus(); }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !pass.text
                                    text: "Password, then Enter"
                                    color: "#8c8680"
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
