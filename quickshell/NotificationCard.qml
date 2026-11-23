import Quickshell.Services.Notifications
import QtQuick

// One notification as a card. Click = `activated`; the x (when closable) only dismisses.
Card {
    id: card
    required property Notification notification
    property string time: ""
    property bool closable: false
    signal activated()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color fg: critical ? "#f2f0eb" : "#1c1c1c"
    height: content.implicitHeight + 24 + offset
    fill: critical ? "#e8335a" : "#f2f0eb"

    MouseArea { anchors.fill: parent; onClicked: card.activated() }

    Column {
        id: content
        x: 12; y: 12
        width: parent.width - 24
        spacing: 4

        Text {
            width: parent.width - (card.closable ? 22 : 0)
            text: card.notification.appName + (card.time ? "  ·  " + card.time : "")
            color: card.critical ? "#f2f0eb" : "#e8335a"
            font.bold: true; font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            width: parent.width - (card.closable ? 22 : 0)
            text: card.notification.summary
            color: card.fg
            font.bold: true; font.pixelSize: 15
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body
            color: card.fg
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
    }

    Text {
        visible: card.closable
        anchors { top: parent.top; right: parent.right; margins: 10 }
        text: String.fromCodePoint(0xf00d) // x
        color: card.fg
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
        MouseArea {
            anchors { fill: parent; margins: -6 }
            onClicked: card.notification.dismiss()
        }
    }
}
