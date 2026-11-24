import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

// Staged idle, in seconds since the last input: dim -> lock -> screen off -> suspend.
// Input undoes dim and screen off. Idle inhibitors (video players, fullscreen video) pause every stage.
// Suspend only on battery: on AC the machine stays reachable (Remote Control, downloads).
// Not a singleton: shell.qml creates it once so the monitors run.
Scope {
    readonly property int dimAfter: 150
    readonly property int lockAfter: 300
    readonly property int screenOffAfter: 330
    readonly property int suspendAfter: 1800

    IdleMonitor {
        timeout: dimAfter
        onIsIdleChanged: isIdle ? Brightness.dim() : Brightness.undim()
    }
    IdleMonitor {
        timeout: lockAfter
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        timeout: screenOffAfter
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
    }
    IdleMonitor {
        timeout: suspendAfter
        onIsIdleChanged: if (isIdle && UPower.onBattery) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
