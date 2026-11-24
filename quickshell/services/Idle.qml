pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

// Staged idle, in seconds since the last input: dim -> lock -> screen off -> suspend.
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

    readonly property int dimAfter: 150
    readonly property int lockAfter: 300
    readonly property int screenOffAfter: 330
    readonly property int suspendAfter: 1800

    IdleMonitor {
        enabled: !root.keepAwake
        timeout: dimAfter
        onIsIdleChanged: isIdle ? Brightness.dim() : Brightness.undim()
    }
    IdleMonitor {
        enabled: !root.keepAwake
        timeout: lockAfter
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: !root.keepAwake
        timeout: screenOffAfter
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
    }
    IdleMonitor {
        enabled: !root.keepAwake
        timeout: suspendAfter
        onIsIdleChanged: if (isIdle && UPower.onBattery) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
