import QtQuick
import QtTest
import "../quickshell/services/SettingsSchema.js" as Schema

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "SettingsSchema"
    readonly property string key: "notifications.timeout"

    function test_defaults_pass_their_own_check() {
        for (const k in Schema.schema) verify(Schema.schema[k].ok(Schema.schema[k].def), k);
    }

    function test_load_data() {
        return [
            { tag: "empty file", text: "", value: 5000, problems: 0 },
            { tag: "empty object", text: "{}", value: 5000, problems: 0 },
            { tag: "valid", text: '{"notifications.timeout": 3000}', value: 3000, problems: 0 },
            { tag: "too small", text: '{"notifications.timeout": 5}', value: 5000, problems: 1 },
            { tag: "too big", text: '{"notifications.timeout": 99999}', value: 5000, problems: 1 },
            { tag: "wrong type", text: '{"notifications.timeout": "3000"}', value: 5000, problems: 1 },
            { tag: "null value", text: '{"notifications.timeout": null}', value: 5000, problems: 1 },
            { tag: "broken JSON", text: '{"notifications.timeout": ', value: 5000, problems: 1 },
            { tag: "key named like an Object method", text: '{"constructor": 1, "toString": 2}', value: 5000, problems: 0 },
            { tag: "not an object", text: '[1]', value: 5000, problems: 1 },
            { tag: "null file", text: 'null', value: 5000, problems: 1 }
        ];
    }
    function test_load(d) {
        const r = Schema.load(d.text);
        compare(r.values[key], d.value);
        compare(r.problems.length, d.problems);
    }

    function test_bad_values_data() {
        return [
            { tag: "volume step 0", key: "sound.volumeStep", bad: 0 },
            { tag: "volume step fraction", key: "sound.volumeStep", bad: 2.5 },
            { tag: "visualizer as text", key: "sound.visualizer", bad: "true" },
            { tag: "idle too short", key: "idle.lock", bad: 10 },
            { tag: "idle negative", key: "idle.suspend", bad: -1 },
            { tag: "hold too long", key: "power.hold", bad: 60000 },
            { tag: "no such position", key: "notifications.position", bad: "bottom-center" }
        ];
    }
    function test_bad_values(d) {
        const r = Schema.load(JSON.stringify({ [d.key]: d.bad }));
        compare(r.values[d.key], Schema.schema[d.key].def);
        compare(r.problems, [d.key]);
    }

    function test_dump_keeps_only_changes_and_unknown_keys() {
        const r = Schema.load('{"notifications.timeout": 3000, "future.key": [1, 2]}');
        compare(JSON.parse(Schema.dump(r.values, r.unknown)), { "notifications.timeout": 3000, "future.key": [1, 2] });
        compare(JSON.parse(Schema.dump(Schema.defaults(), {})), {});
    }
}
