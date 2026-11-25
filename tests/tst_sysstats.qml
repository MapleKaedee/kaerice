import QtQuick
import QtTest
import "../quickshell/services/SysStatsState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
TestCase {
    name: "SysStatsState"

    function test_view() {
        const v = State.view({
            cpu: { idle: 450, total: 622 },
            mem: { total: 17179869184, available: 4294967296 },
            disk: { total: 507812773888, used: 222554058752, available: 279475474432 },
            uptime: 24214
        });
        compare(v.mem, 0.75);
        compare(v.memTotalGb, 16);
        compare(v.memUsedGb, 12);
        compare(v.disk, 0.45, "44.33% is 45% in df");
        compare(Math.round(v.diskTotalGb), 473);
        compare(Math.round(v.diskUsedGb), 207);
        compare(v.uptime, 24214);
    }

    function test_unknown_data() {
        return [
            { tag: "nothing", data: undefined },
            { tag: "null", data: null },
            { tag: "number", data: 5 },
            { tag: "empty", data: {} },
            { tag: "empty parts", data: { mem: {}, disk: {}, uptime: 5 } },
            { tag: "no disk", data: { mem: { total: 2, available: 1 } } }
        ];
    }

    function test_unknown(d) {
        compare(State.view(d.data), { mem: -1, memUsedGb: 0, memTotalGb: 0, disk: -1, diskUsedGb: 0, diskTotalGb: 0, uptime: 0 });
    }

    function test_cpu_data() {
        const old = { idle: 100, total: 200 };
        return [
            { tag: "half", before: old, now: { idle: 150, total: 300 }, cpu: 0.5 },
            { tag: "idle", before: old, now: { idle: 200, total: 300 }, cpu: 0 },
            { tag: "busy", before: old, now: { idle: 100, total: 300 }, cpu: 1 },
            { tag: "first sample", before: undefined, now: old, cpu: -1 },
            { tag: "same sample", before: old, now: old, cpu: -1 },
            { tag: "counters went back", before: old, now: { idle: 5, total: 10 }, cpu: -1 },
            { tag: "no answer", before: old, now: undefined, cpu: -1 }
        ];
    }

    function test_cpu(d) {
        compare(State.cpu(d.before, d.now), d.cpu);
    }
}
