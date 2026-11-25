pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "SysStatsState.js" as State

// CPU / RAM / root-disk usage and uptime from kaericed, read every 2 s while the dashboard or control center is open.
Singleton {
    id: root
    property var stats             // the last answer, undefined when there is none
    property var lastCpu           // the sample before
    readonly property var view: State.view(stats)
    property real cpu: -1          // 0..1, -1 until two samples exist
    readonly property real mem: view.mem           // 0..1, -1 = unknown
    readonly property real memUsedGb: view.memUsedGb
    readonly property real memTotalGb: view.memTotalGb
    readonly property real disk: view.disk         // 0..1, -1 = unknown
    readonly property real diskUsedGb: view.diskUsedGb
    readonly property real diskTotalGb: view.diskTotalGb
    readonly property int uptime: view.uptime      // seconds
    readonly property string uptimeText: {
        const d = Math.floor(uptime / 86400), h = Math.floor(uptime % 86400 / 3600), m = Math.floor(uptime % 3600 / 60);
        return "up " + (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
    }
    property string host: hostFile.text().trim()

    function take(code, data) {
        if (!poll.running) return; // closed meanwhile
        root.stats = code === "" ? data : undefined;
        root.cpu = State.cpu(root.lastCpu, root.stats?.cpu);
        root.lastCpu = root.stats?.cpu;
    }

    Timer {
        id: poll
        interval: 2000; repeat: true; triggeredOnStart: true
        running: Ui.dashboard || Ui.controlCenter
        onTriggered: Backend.call("stats.read", {}, (code, data) => root.take(code, data))
        onRunningChanged: if (!running) { root.lastCpu = undefined; root.cpu = -1; }
    }

    FileView { id: hostFile; path: "/etc/hostname" }
}
