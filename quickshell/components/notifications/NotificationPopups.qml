import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.services

// Popup cards at top-right for fresh notifications (Notifs.shown). Each hides after Notifs.timeout.
PanelWindow {
    visible: Notifs.shown.length > 0
    anchors { top: true; right: true }
    margins { top: 8; right: 14 }
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
