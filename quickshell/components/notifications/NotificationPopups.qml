import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.services

// Popup cards for fresh notifications (Notifs.shown), in the corner chosen in settings. Each hides after Notifs.timeout.
PanelWindow {
    readonly property var position: Settings.get("notifications.position").split("-") // e.g. ["top", "right"]; center = neither side
    visible: Notifs.shown.length > 0
    anchors { top: position[0] === "top"; bottom: position[0] === "bottom"; left: position[1] === "left"; right: position[1] === "right" }
    margins { top: 8; bottom: 8; left: 14; right: 14 }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: popups.implicitHeight
    color: "transparent"

    Column {
        id: popups
        width: parent.width
        spacing: 10

        Repeater {
            model: Notifs.list

            NotificationCard {
                id: popup
                required property Notification modelData
                readonly property int nid: modelData.id
                notification: modelData
                width: popups.width
                visible: Notifs.shown.indexOf(nid) >= 0
                onActivated: Notifs.activate(modelData)

                Timer {
                    running: !popup.critical
                    interval: Notifs.timeout
                    onTriggered: Notifs.hide(popup.nid)
                }
                Component.onDestruction: Notifs.hide(popup.nid)
            }
        }
    }
}
