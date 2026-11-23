import QtQuick

// Card with an optional Nerd Font icon and one bold label; width follows the content.
Card {
    id: root
    property alias text: label.text
    property string icon: ""
    property color textColor: "#1c1c1c"
    width: row.implicitWidth + 28 + offset
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
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            color: root.textColor
            font.pixelSize: 14; font.bold: true
        }
    }
}
