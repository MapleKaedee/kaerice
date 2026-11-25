import QtQuick
import QtTest
import "../quickshell/services/BackendState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
// The lines are the ones core/src/server.rs checks: change both.
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
        const topics = State.merge({}, d.line);
        compare(topics.network.kind, d.kind);
        compare(topics.network.ssid, d.ssid);
    }

    function test_other_topics_stay() {
        const before = { a: 1, network: { kind: "eth" } };
        const after = State.merge(before, '{"network":{"kind":"offline"}}');
        compare(after.a, 1);
        compare(after.network.kind, "offline");
        compare(before.network.kind, "eth", "the old object is not changed");
    }

    function test_unusable_lines_data() {
        return ["", "{", "5", "\"x\"", "[]", "null", "true"].map(line => ({ tag: line || "empty", line: line }));
    }

    function test_unusable_lines(d) {
        compare(State.merge({ a: 1 }, d.line), null);
    }
}
