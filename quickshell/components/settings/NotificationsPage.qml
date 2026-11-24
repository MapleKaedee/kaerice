import QtQuick
import qs.services
import qs.components.base

// Popup time and place, Silent (the same toggle as in the control center).
Column {
    spacing: 14

    SettingRow {
        label: "Popup time"
        hint: "Critical popups stay until clicked"
        Stepper {
            values: [2, 3, 4, 5, 6, 8, 10, 15, 20, 30].map(s => s * 1000)
            value: Settings.get("notifications.timeout")
            format: v => v / 1000 + " s"
            onPicked: v => Settings.set("notifications.timeout", v)
        }
    }
    SettingRow {
        label: "Popup position"
        hint: Settings.get("notifications.position").replace("-", " ")
        Choice {
            options: [
                { value: "top-left", label: "↖" }, { value: "top-center", label: "↑" }, { value: "top-right", label: "↗" },
                { value: "bottom-left", label: "↙" }, { value: "bottom-right", label: "↘" }
            ]
            value: Settings.get("notifications.position")
            onPicked: v => Settings.set("notifications.position", v)
        }
    }
    SettingRow {
        label: "Silent"
        hint: "No popups except critical ones. Everything still lands in the history."
        Choice {
            value: Notifs.dnd
            onPicked: v => Notifs.dnd = v
        }
    }
}
