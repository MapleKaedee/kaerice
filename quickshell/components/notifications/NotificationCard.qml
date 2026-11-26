import Quickshell.Services.Notifications
import QtQuick
import qs.config
import qs.components.base

// One notification as a card. Click = `activated`; the x (when closable) only dismisses.
Card {
    id: card
    required property Notification notification
    property string time: ""
    property bool closable: false
    signal activated()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color fg: critical ? Theme.accentText : Theme.text
    height: content.implicitHeight + 24 + offset
    fill: critical ? Theme.accent : Theme.face

    MouseArea { anchors.fill: parent; onClicked: card.activated() }

    // PlainText: apps send markup unasked, and rich text fetches <img> URLs, telling the sender we saw it
    Column {
        id: content
        x: 12; y: 12
        width: parent.width - 24
        spacing: 4

        Text {
            width: parent.width - (card.closable ? 22 : 0)
            text: card.notification.appName + (card.time ? "  ·  " + card.time : "")
            textFormat: Text.PlainText
            color: card.critical ? Theme.accentText : Theme.highlight
            font.bold: true; font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            width: parent.width - (card.closable ? 22 : 0)
            text: card.notification.summary
            textFormat: Text.PlainText
            color: card.fg
            font.bold: true; font.pixelSize: 15
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body
            textFormat: Text.PlainText
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
        font.family: Theme.iconFont; font.pixelSize: 14
        MouseArea {
            anchors { fill: parent; margins: -6 }
            onClicked: card.notification.dismiss()
        }
    }
}
