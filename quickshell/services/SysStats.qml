pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// CPU / RAM / root-disk usage and uptime, polled every 2 s while the dashboard or control center is open.
Singleton {
    id: root
    property real cpu: -1          // 0..1, -1 until two samples exist
    property real mem: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real disk: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property int uptime: 0         // seconds
    readonly property string uptimeText: {
        const d = Math.floor(uptime / 86400), h = Math.floor(uptime % 86400 / 3600), m = Math.floor(uptime % 3600 / 60);
        return "up " + (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
    }
    property string host: hostFile.text().trim()
    property var lastCpu: null     // [idle, total] of the previous /proc/stat sample

    function parse(text) {
        const lines = text.trim().split("\n");
        const c = lines[0].split(/\s+/).slice(1).map(Number);
        const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0);
        if (root.lastCpu && total > root.lastCpu[1])
            root.cpu = 1 - (idle - root.lastCpu[0]) / (total - root.lastCpu[1]);
        root.lastCpu = [idle, total];

        const kb = l => Number(l.split(/\s+/)[1]);
        const memTotal = kb(lines[1]), memAvail = kb(lines[2]);
        root.mem = 1 - memAvail / memTotal;
        root.memTotalGb = memTotal / 1048576;
        root.memUsedGb = (memTotal - memAvail) / 1048576;

        const df = lines[3].split(/\s+/); // 1K-blocks used available capacity
        root.disk = parseInt(df[4]) / 100;
        root.diskTotalGb = Number(df[1]) / 1048576;
        root.diskUsedGb = Number(df[2]) / 1048576;
        root.uptime = Math.floor(Number(lines[4].split(" ")[0]));
    }

    Process {
        id: proc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -P / | tail -1; cat /proc/uptime"]
        stdout: StdioCollector { id: out; onStreamFinished: root.parse(out.text) }
    }

    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: Ui.dashboard || Ui.controlCenter
        onTriggered: proc.running = true
        onRunningChanged: if (!running) { root.lastCpu = null; root.cpu = -1; }
    }

    FileView { id: hostFile; path: "/etc/hostname" }
}
