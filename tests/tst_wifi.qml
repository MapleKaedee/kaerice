import QtQuick
import QtTest
import "../quickshell/services/WifiState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "WifiState"

    readonly property var home: ({ path: "/p", name: "home", type: "psk", known: true, connected: true, dbm: -59 })

    function test_note_data() {
        const on = { device: "wlan0", powered: true, scanning: false, networks: [home] };
        return [
            { tag: "down", payload: on, down: true, note: "Unavailable: kaericed is not running" },
            { tag: "nothing received", payload: undefined, down: false, note: "Waiting for kaericed. If this stays, run ./install.sh" },
            { tag: "no device", payload: { device: null, powered: false, scanning: false, networks: [] }, down: false, note: "No Wi-Fi device found" },
            { tag: "off", payload: { device: "wlan0", powered: false, scanning: false, networks: [] }, down: false, note: "Wi-Fi is off" },
            { tag: "scanning", payload: { device: "wlan0", powered: true, scanning: true, networks: [] }, down: false, note: "Scanning…" },
            { tag: "on", payload: on, down: false, note: "" }
        ];
    }

    function test_note(d) {
        compare(State.view(d.payload, d.down).note, d.note);
    }

    function test_view() {
        const v = State.view({ device: "wlan0", powered: true, scanning: true, networks: [home] }, false);
        compare(v.device, "wlan0");
        compare(v.powered, true);
        compare(v.networks.length, 1);
        compare(v.networks[0].name, "home");
    }

    function test_nothing_to_press_without_state_data() {
        const on = { device: "wlan0", powered: true, scanning: true, networks: [home] };
        return [
            { tag: "down", payload: on, down: true },
            { tag: "undefined", payload: undefined, down: false },
            { tag: "null", payload: null, down: false },
            { tag: "number", payload: 5, down: false },
            { tag: "no device", payload: { device: null, powered: false, scanning: false, networks: [] }, down: false }
        ];
    }

    function test_networks_that_are_no_list() {
        verify(Array.isArray(State.view({ device: "wlan0", powered: true, networks: {} }, false).networks));
    }

    function test_nothing_to_press_without_state(d) {
        const v = State.view(d.payload, d.down);
        compare(v.device, "");
        compare(v.powered, false);
        compare(v.networks, []);
    }

    function test_error_text_data() {
        return [
            { tag: "no error", code: "", password: true, text: "" },
            { tag: "short password", code: "InvalidFormat", password: true, text: "The password must have 8 to 63 characters" },
            { tag: "new network", code: "Failed", password: true, text: "Could not connect. Is the password right?" },
            { tag: "known network", code: "Failed", password: false, text: "Failed" },
            { tag: "no iwd", code: "Unavailable", password: false, text: "iwd is not running" },
            { tag: "hung", code: "Timeout", password: true, text: "iwd did not answer" },
            { tag: "busy", code: "Busy", password: true, text: "Still connecting to another network" },
            { tag: "in progress", code: "InProgress", password: false, text: "Still connecting to another network" },
            { tag: "daemon left", code: "Disconnected", password: true, text: "Unavailable: kaericed is not running" },
            { tag: "old daemon", code: "UnknownCall", password: false, text: "Run ./install.sh to update kaericed" },
            { tag: "any other", code: "NoAgent", password: false, text: "Failed: NoAgent" }
        ];
    }

    function test_error_text(d) {
        compare(State.errorText(d.code, d.password), d.text);
    }
}
