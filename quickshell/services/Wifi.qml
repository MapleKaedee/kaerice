pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// iwd Wi-Fi state and actions. State comes from iwd's D-Bus API (busctl JSON); actions run through iwctl.
// Refreshes every 3 s while the Wi-Fi menu is open.
// shortcut: the passphrase is passed to iwctl as an argument, so it is visible in the process list
// for the few seconds the connect takes; switch to an iwd D-Bus agent if that matters.
Singleton {
    id: root
    property string device: ""     // interface name for iwctl, e.g. wlan0
    property string station: ""    // D-Bus path of the station (empty while Wi-Fi is off)
    property bool powered: false
    property bool scanning: false
    property string connected: ""  // D-Bus path of the connected network
    property var objects: ({})
    property var networks: []      // [{ path, name, type, known, connected, dbm }] strongest first
    property string status: ""     // progress or error message of the last action
    readonly property bool busy: action.running

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
        act(pass ? ["--passphrase", pass, "station", root.device, "connect", n.name]
                 : ["station", root.device, "connect", n.name], "Connecting to " + n.name + "…");
    }
    function disconnect() { act(["station", root.device, "disconnect"], "Disconnecting…"); }
    function togglePower() {
        act(["device", root.device, "set-property", "Powered", root.powered ? "off" : "on"],
            root.powered ? "Turning Wi-Fi off…" : "Turning Wi-Fi on…");
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
        running: Ui.wifi
        repeat: true
        onTriggered: root.refresh()
    }
}
