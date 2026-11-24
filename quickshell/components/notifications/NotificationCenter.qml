import QtQuick
import qs.config
import qs.services
import qs.components.base

// Notification history panel (top-right): do-not-disturb, clear all, newest first.
Overlay {
    name: "notifications"
    visible: Ui.notifications
    onDismissed: Ui.notifications = false

    Card {
        x: parent.width - width - 14
        y: 60
        width: 400
        height: col.implicitHeight + 24 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the panel

        Column {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10

            // header: title, do-not-disturb, clear all
            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    Card {
                        width: 38; height: 36; offset: Theme.depth(3)
                        fill: Notifs.dnd ? Theme.accent : Theme.face
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(Notifs.dnd ? 0xf1f6 : 0xf0f3) // bell-slash / bell
                            color: Notifs.dnd ? Theme.accentText : Theme.text
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        MouseArea { anchors.fill: parent; onClicked: Notifs.dnd = !Notifs.dnd }
                    }
                    Card {
                        visible: Notifs.count > 0
                        width: 38; height: 36; offset: Theme.depth(3)
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xf1f8) // trash
                            color: Theme.text
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        MouseArea { anchors.fill: parent; onClicked: Notifs.clearAll() }
                    }
                }
            }

            Text {
                visible: Notifs.count === 0 || Notifs.dnd
                text: Notifs.count === 0 ? "No notifications" : "Do not disturb is on"
                color: Theme.text
                opacity: 0.75
                font.pixelSize: 13
            }

            ListView {
                id: history
                width: parent.width
                height: Math.min(contentHeight, 560)
                visible: count > 0
                clip: true
                spacing: 10
                model: Notifs.list.values.slice().reverse() // newest first

                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: history.width
                    time: Notifs.times[modelData.id] || ""
                    closable: true
                    onActivated: Notifs.activate(modelData)
                }
            }
        }
    }
}
