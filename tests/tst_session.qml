import QtQuick
import QtTest
import "../quickshell/services/SessionState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "SessionState"

    readonly property string packages: "A package manager is running: stopping now can break the update."
    readonly property string downloads: "Downloads are in progress."
    readonly property string unknown: "Could not check for package updates or downloads."

    function test_warnings_data() {
        return [
            { tag: "nothing", code: "", data: { downloads: false, packages: false }, warnings: [] },
            { tag: "packages", code: "", data: { downloads: false, packages: true }, warnings: [packages] },
            { tag: "downloads", code: "", data: { downloads: true, packages: false }, warnings: [downloads] },
            { tag: "both", code: "", data: { downloads: true, packages: true }, warnings: [packages, downloads] },
            { tag: "daemon is down", code: "Disconnected", data: undefined, warnings: [unknown] },
            { tag: "older daemon", code: "UnknownCall", data: undefined, warnings: [unknown] },
            { tag: "could not look", code: "Failed", data: undefined, warnings: [unknown] },
            { tag: "no data", code: "", data: undefined, warnings: [unknown] },
            { tag: "null", code: "", data: null, warnings: [unknown] },
            { tag: "half of it", code: "", data: { packages: false }, warnings: [unknown] }
        ];
    }

    function test_warnings(d) {
        compare(State.warnings(d.code, d.data), d.warnings);
    }
}
