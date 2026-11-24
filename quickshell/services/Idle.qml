pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

// Staged idle, in seconds since the last input: dim -> lock -> screen off -> suspend.
// Input undoes dim and screen off. Idle inhibitors (video players, fullscreen video) pause every stage.
// Suspend only on battery: on AC the machine stays reachable (Remote Control, downloads).
// keepAwake (control center) pauses every stage. shell.qml reads it at startup so the monitors run from the start.
Singleton {
    id: root
    property bool keepAwake: false
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
