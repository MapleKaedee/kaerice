import QtQuick
import QtTest
import "../quickshell/services/BrightnessState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "BrightnessState"

    function test_level_data() {
        return [
            { tag: "normal", payload: { percent: 55 }, level: 55 },
            { tag: "set to 0 from outside", payload: { percent: 0 }, level: 0 },
            { tag: "full", payload: { percent: 100 }, level: 100 },
            { tag: "nothing received, down or no backlight", payload: undefined, level: -1 },
            { tag: "null", payload: null, level: -1 },
            { tag: "number", payload: 5, level: -1 },
            { tag: "empty", payload: {}, level: -1 },
            { tag: "text", payload: { percent: "55" }, level: -1 },
            { tag: "too high", payload: { percent: 101 }, level: -1 },
            { tag: "negative", payload: { percent: -1 }, level: -1 }
        ];
    }

    function test_level(d) {
        compare(State.level(d.payload), d.level);
    }

    function test_clamp_data() {
        return [
            { tag: "never black", p: 0, level: 1 },
            { tag: "negative", p: -5, level: 1 },
            { tag: "lowest", p: 1, level: 1 },
            { tag: "rounded", p: 54.6, level: 55 },
            { tag: "too high", p: 150, level: 100 }
        ];
    }

    function test_clamp(d) {
        compare(State.clamp(d.p), d.level);
    }
}
