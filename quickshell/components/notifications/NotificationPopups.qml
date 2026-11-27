import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.services

// Popup cards for fresh notifications (Notifs.shown), in the corner chosen in settings. Each hides after Notifs.timeout.
PanelWindow {
    id: root
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
        // later: Column sets implicitHeight while it lays out, and fit() removes a child
        onImplicitHeightChanged: Qt.callLater(popups.fit)

        // too tall for the screen: hide the oldest popup that is not critical (it stays in the history)
        function fit() {
            if (!root.screen || cards.count < 2 || implicitHeight <= root.screen.height - BarLayout.height - root.margins.top - root.margins.bottom)
                return;
            let old = cards.itemAt(0);
            for (let i = 0; i < cards.count; i++)
                if (!cards.itemAt(i).critical) { old = cards.itemAt(i); break; }
            Notifs.hide(old.nid);
        }

        Repeater {
            id: cards
            // ScriptModel: cards that stay shown keep their timers when another one comes or goes
            model: ScriptModel { values: Notifs.list.values.filter(n => Notifs.shown.indexOf(n.id) >= 0) }

            NotificationCard {
                id: popup
                required property Notification modelData
                readonly property int nid: modelData.id
                notification: modelData
                width: popups.width
                onActivated: Notifs.activate(modelData)

                Timer {
                    running: !popup.critical
                    interval: Notifs.timeout
                    onTriggered: Notifs.hide(popup.nid)
                }
            }
        }
    }
}
