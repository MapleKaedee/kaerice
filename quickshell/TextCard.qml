import QtQuick

// Card with one bold label; width follows the text.
Card {
    id: root
    property alias text: label.text
    property color textColor: "#1c1c1c"
    width: label.implicitWidth + 28 + offset
    height: 38

    Text {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.pixelSize: 14; font.bold: true
    }
}
