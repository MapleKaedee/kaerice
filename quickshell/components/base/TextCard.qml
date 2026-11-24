import QtQuick
import qs.config

// Card with an optional Nerd Font icon and one bold label; width follows the content.
Card {
    id: root
    property alias text: label.text
    property string icon: ""
    property color textColor: Theme.ink
    property int maxTextWidth: 0 // 0 = no limit; longer text is elided
    width: row.width + 28 + offset
    height: 38

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.textColor
            font.family: Theme.iconFont
            font.pixelSize: 17
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: root.maxTextWidth > 0 ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
            elide: Text.ElideRight
            color: root.textColor
            font.pixelSize: 14; font.bold: true
        }
    }
}
