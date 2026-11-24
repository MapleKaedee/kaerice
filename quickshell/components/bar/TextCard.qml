import QtQuick
import qs.config
import qs.components.base

// Bar card with an optional Nerd Font icon and one bold label; width follows the content.
Card {
    id: root
    property alias text: label.text
    property string icon: ""
    property color textColor: Theme.text
    property int maxTextWidth: 0 // 0 = no limit; longer text is elided
    width: row.width + Theme.bar(28) + offset
    height: Theme.bar(38); offset: Theme.bar(Theme.shadow)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.bar(8)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.textColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.bar(17)
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: root.maxTextWidth > 0 ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
            elide: Text.ElideRight
            color: root.textColor
            font.pixelSize: Theme.bar(14); font.bold: true
        }
    }
}
