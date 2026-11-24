import QtQuick
import QtTest
import "../quickshell/services/BatteryLevels.js" as Levels

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "BatteryLevels"

    function test_next_data() {
        return [
            { tag: "above every level", percent: 21, onBattery: true, warned: 0, expWarned: 0, expNotify: 0 },
            { tag: "reaches 20", percent: 20, onBattery: true, warned: 0, expWarned: 20, expNotify: 20 },
            { tag: "same level only once", percent: 15, onBattery: true, warned: 20, expWarned: 20, expNotify: 0 },
            { tag: "next level", percent: 10, onBattery: true, warned: 20, expWarned: 10, expNotify: 10 },
            { tag: "skips levels after a jump", percent: 4, onBattery: true, warned: 20, expWarned: 5, expNotify: 5 },
            { tag: "last level", percent: 3, onBattery: true, warned: 5, expWarned: 3, expNotify: 3 },
            { tag: "no flapping around a level", percent: 11, onBattery: true, warned: 10, expWarned: 10, expNotify: 0 },
            { tag: "charged meanwhile, still low", percent: 16, onBattery: true, warned: 5, expWarned: 20, expNotify: 0 },
            { tag: "charged meanwhile, high", percent: 80, onBattery: true, warned: 5, expWarned: 0, expNotify: 0 },
            { tag: "plugging in resets", percent: 4, onBattery: false, warned: 5, expWarned: 0, expNotify: 0 },
            { tag: "low while plugged in", percent: 2, onBattery: false, warned: 0, expWarned: 0, expNotify: 0 }
        ];
    }

    function test_next(d) {
        const r = Levels.next(d.percent, d.onBattery, d.warned);
        compare(r.warned, d.expWarned, "warned");
        compare(r.notify, d.expNotify, "notify");
    }
}
