import QtQuick
import qs.services

// Idle stages (kept in order) and how long to hold an action in the power menu.
Column {
    spacing: 14

    SettingRow {
        label: "When idle"
        hint: "Counted from the last input. Each step comes after the one above it."
            + (Idle.keepAwake ? " Paused now: Awake is on in the control center." : "")
    }
    Repeater {
        model: ["Dim the screen", "Lock", "Turn the screen off", "Suspend"]
        SettingRow {
            id: stage
            required property string modelData
            required property int index
            label: modelData
            hint: index === 3 ? "On battery only" : ""
            Stepper { // never is last in the list, stored as 0
                values: Idle.allowed(stage.index).concat([Infinity])
                value: Idle.times[stage.index] || Infinity
                format: Idle.timeText
                onPicked: v => Idle.setTime(stage.index, isFinite(v) ? v : 0)
            }
        }
    }
    Item { width: 1; height: 4 }

    SettingRow {
        label: "Hold to confirm"
        hint: "Suspend, Logout, Reboot and Shutdown in the power menu. While packages or downloads run, the last three take 2 s longer."
        Stepper {
            values: [0, 500, 1000, 1500, 2000, 3000]
            value: Settings.get("power.hold")
            format: v => v ? v / 1000 + " s" : "Off"
            onPicked: v => Settings.set("power.hold", v)
        }
    }
}
