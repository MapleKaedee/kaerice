import QtQuick
import QtTest
import "../quickshell/services/IdleStages.js" as Stages
import "../quickshell/services/SettingsSchema.js" as Schema

TestCase {
    name: "IdleStages"
    readonly property var defs: Stages.keys.map(k => Schema.schema[k].def)

    function test_defaults_are_choices_in_order() {
        for (let i = 0; i < defs.length; i++) {
            verify(Stages.choices.includes(defs[i]), Stages.keys[i]);
            verify(Stages.allowed(defs, i).includes(defs[i]), Stages.keys[i]);
        }
    }

    function test_choices_pass_the_schema() {
        for (const k of Stages.keys) for (const c of Stages.choices.concat([0])) verify(Schema.schema[k].ok(c), k + " " + c);
    }

    function test_allowed_data() {
        return [
            { tag: "dim stays before lock", times: [150, 300, 330, 1800], i: 0, min: 30, max: 240 },
            { tag: "lock between dim and screen off", times: [150, 300, 330, 1800], i: 1, min: 180, max: 300 },
            { tag: "suspend after screen off", times: [150, 300, 330, 1800], i: 3, min: 360, max: 7200 },
            { tag: "never does not limit", times: [150, 0, 330, 1800], i: 0, min: 30, max: 300 },
            { tag: "from never", times: [150, 0, 330, 1800], i: 1, min: 180, max: 300 },
            { tag: "all others never", times: [0, 300, 0, 0], i: 1, min: 30, max: 7200 }
        ];
    }
    function test_allowed(d) {
        const a = Stages.allowed(d.times, d.i);
        compare(a[0], d.min);
        compare(a[a.length - 1], d.max);
    }

    function test_text_data() {
        return [
            { tag: "never", s: 0, out: "Never" }, { tag: "infinity", s: Infinity, out: "Never" },
            { tag: "seconds", s: 30, out: "30 s" }, { tag: "minute", s: 60, out: "1 min" },
            { tag: "half", s: 150, out: "2.5 min" }, { tag: "odd", s: 100, out: "1.7 min" },
            { tag: "hour", s: 3600, out: "1 h" }, { tag: "hours", s: 5400, out: "1.5 h" }
        ];
    }
    function test_text(d) { compare(Stages.text(d.s), d.out); }
}
