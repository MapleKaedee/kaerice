pragma Singleton

import Quickshell
import QtQuick
import "WifiState.js" as State

// iwd Wi-Fi state and actions, through kaericed.
Singleton {
    id: root
    readonly property var view: State.view(Backend.topics.wifi, Backend.down)
    readonly property string device: view.device    // interface name, e.g. wlan0
    readonly property bool powered: view.powered
    readonly property var networks: view.networks   // [{ path, name, type, known, connected, dbm }] strongest first
    property string status: ""                      // progress or error message of the last action
    readonly property string note: status || view.note
    property bool busy: false

    function scan() {
        if (root.powered) Backend.call("wifi.scan", {}, () => {});
    }

    function act(call, args, doing) {
        if (root.busy) return;
        root.busy = true;
        root.status = doing;
        Backend.call(call, args, code => {
            root.busy = false;
            root.status = State.errorText(code, "passphrase" in args);
        });
    }

    function connect(n, pass) {
        act("wifi.connect", pass ? { path: n.path, passphrase: pass } : { path: n.path }, "Connecting to " + n.name + "…");
    }
    function disconnect() { act("wifi.disconnect", {}, "Disconnecting…"); }
    function togglePower() {
        act("wifi.power", { on: !root.powered }, root.powered ? "Turning Wi-Fi off…" : "Turning Wi-Fi on…");
    }
}
