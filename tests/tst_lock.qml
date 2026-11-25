import QtQuick
import QtTest
import "../quickshell/services/BackendState.js" as Backend
import "../quickshell/services/LockState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
// The lines are the ones core/src/sleep.rs checks: change both.
TestCase {
    name: "LockState"

    function test_lines_data() {
        return [
            { tag: "awake", line: '{"sleep":{"preparing":false}}', guarded: true, preparing: false },
            { tag: "preparing", line: '{"sleep":{"preparing":true}}', guarded: true, preparing: true },
            { tag: "cannot hold", line: '{"sleep":null}', guarded: false, preparing: false }
        ];
    }

    function test_lines(d) {
        const payload = Backend.merge({}, Backend.parse(d.line)).sleep;
        compare(State.guarded(payload), d.guarded);
        compare(State.preparing(payload), d.preparing);
    }

    // anything unknown means that nobody holds the suspend
    function test_unusable_data() {
        return [
            { tag: "older daemon", payload: undefined },
            { tag: "empty", payload: {} },
            { tag: "text", payload: { preparing: "true" } },
            { tag: "number", payload: 5 }
        ];
    }

    function test_unusable(d) {
        compare(State.guarded(d.payload), false);
        compare(State.preparing(d.payload), false);
    }
}
