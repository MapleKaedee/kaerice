pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import "IdleStages.js" as Stages

// Staged idle, in seconds since the last input: dim -> lock -> screen off -> suspend. Times come from settings
// (0 = never).
// Input undoes dim and screen off. Idle inhibitors (video players, fullscreen video) pause every stage.
// Suspend only on battery: on AC the machine stays reachable (Remote Control, downloads).
// keepAwake (control center) pauses every stage. shell.qml reads it at startup so the monitors run from the start.
// keepAwake survives reloads and restarts within one login: it is saved with the session id, so a new login starts off.
Singleton {
    id: root
    readonly property string session: Quickshell.env("XDG_SESSION_ID") || "on"
    property bool keepAwake: saved.text().trim() === session
    onKeepAwakeChanged: saved.setText(keepAwake ? session : "")

    FileView {
        id: saved
        path: Quickshell.statePath("keep-awake")
        blockLoading: true
        printErrors: false
    }

    readonly property var times: Stages.keys.map(k => Settings.get(k)) // dim, lock, screen off, suspend
    function allowed(stage) { return Stages.allowed(times, stage); }   // choices that keep the stages in order
    function setTime(stage, seconds) { Settings.set(Stages.keys[stage], seconds); }
    function timeText(seconds) { return Stages.text(seconds); }

    // IdleMonitor ignores a timeout that changes while it is enabled: stop, take over the times, start again
    property var active: [0, 0, 0, 0] // times in use
    property bool restarting: true
    readonly property string wanted: times.join()
    onWantedChanged: { restarting = true; Qt.callLater(restart); }
    Component.onCompleted: restart()
    function restart() { active = times; restarting = false; }
    function runs(stage) { return !restarting && !keepAwake && active[stage] > 0; }
    function seconds(stage) { return active[stage] || 86400; } // never 0: it would fire before it is disabled

    IdleMonitor {
        enabled: root.runs(0)
        timeout: root.seconds(0)
        onIsIdleChanged: isIdle ? Brightness.dim() : Brightness.undim()
    }
    IdleMonitor {
        enabled: root.runs(1)
        timeout: root.seconds(1)
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: root.runs(2)
        timeout: root.seconds(2)
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
    }
    IdleMonitor {
        enabled: root.runs(3)
        timeout: root.seconds(3)
        onIsIdleChanged: if (isIdle && UPower.onBattery) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
