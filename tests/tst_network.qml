import QtQuick
import QtTest
import "../quickshell/services/NetworkState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "NetworkState"

    function test_view_data() {
        return [
            { tag: "down", payload: { kind: "eth", ssid: null }, down: true, kind: "unavailable", label: "N/A" },
            { tag: "down, nothing received", payload: undefined, down: true, kind: "unavailable", label: "N/A" },
            { tag: "nothing received yet", payload: undefined, down: false, kind: "wifi", label: "NET" },
            { tag: "null", payload: null, down: false, kind: "wifi", label: "NET" },
            { tag: "not an object", payload: 5, down: false, kind: "wifi", label: "NET" },
            { tag: "kind of a newer daemon", payload: { kind: "future" }, down: false, kind: "wifi", label: "NET" },
            { tag: "eth", payload: { kind: "eth", ssid: null }, down: false, kind: "eth", label: "ETH" },
            { tag: "wifi", payload: { kind: "wifi", ssid: "home" }, down: false, kind: "wifi", label: "home" },
            { tag: "long ssid", payload: { kind: "wifi", ssid: "abcdefghijklmnop" }, down: false, kind: "wifi", label: "abcdefghijklmn" },
            { tag: "no ssid", payload: { kind: "wifi", ssid: null }, down: false, kind: "wifi", label: "WIFI" },
            { tag: "empty ssid", payload: { kind: "wifi", ssid: "" }, down: false, kind: "wifi", label: "WIFI" },
            { tag: "offline", payload: { kind: "offline", ssid: null }, down: false, kind: "offline", label: "OFFLINE" }
        ];
    }

    function test_view(d) {
        const v = State.view(d.payload, d.down);
        compare(v.kind, d.kind);
        compare(v.label, d.label);
    }
}
