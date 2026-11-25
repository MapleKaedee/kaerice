import QtQuick
import QtTest
import "../quickshell/services/BackendState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
// The lines are the ones core/src/server.rs and wifi.rs check: change both.
TestCase {
    name: "BackendState"

    function test_topic_lines_data() {
        return [
            { tag: "eth", line: '{"network":{"kind":"eth","ssid":null}}', kind: "eth", ssid: null },
            { tag: "wifi", line: '{"network":{"kind":"wifi","ssid":"home"}}', kind: "wifi", ssid: "home" },
            { tag: "offline", line: '{"network":{"kind":"offline","ssid":null}}', kind: "offline", ssid: null }
        ];
    }

    function test_topic_lines(d) {
        const topics = State.merge({}, State.parse(d.line));
        compare(topics.network.kind, d.kind);
        compare(topics.network.ssid, d.ssid);
    }

    function test_wifi_line() {
        const line = '{"wifi":{"device":"wlan0","powered":true,"scanning":false,"networks":[{"path":"/net/connman/iwd/0/3/home_psk","name":"home","type":"psk","known":true,"connected":true,"dbm":-59}]}}';
        const wifi = State.merge({}, State.parse(line)).wifi;
        compare(wifi.device, "wlan0");
        compare(wifi.networks[0], { path: "/net/connman/iwd/0/3/home_psk", name: "home", type: "psk", known: true, connected: true, dbm: -59 });
    }

    function test_answer_lines_data() {
        return [
            { tag: "ok", line: '{"id":7,"ok":true}', code: "" },
            { tag: "error", line: '{"id":7,"error":"Failed"}', code: "Failed" },
            { tag: "neither", line: '{"id":7}', code: "Failed" }
        ];
    }

    function test_answer_lines(d) {
        const message = State.parse(d.line);
        verify(State.isAnswer(message));
        compare(message.id, 7);
        compare(State.code(message), d.code);
    }

    function test_topic_is_no_answer() {
        verify(!State.isAnswer(State.parse('{"network":{"kind":"offline","ssid":null}}')));
    }

    function test_other_topics_stay() {
        const before = { a: 1, network: { kind: "eth" } };
        const after = State.merge(before, { network: { kind: "offline" } });
        compare(after.a, 1);
        compare(after.network.kind, "offline");
        compare(before.network.kind, "eth", "the old object is not changed");
    }

    function test_unusable_lines_data() {
        return ["", "{", "5", "\"x\"", "[]", "null", "true"].map(line => ({ tag: line || "empty", line: line }));
    }

    function test_unusable_lines(d) {
        compare(State.parse(d.line), null);
    }
}
