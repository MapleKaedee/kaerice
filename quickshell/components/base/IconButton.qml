import QtQuick
import qs.config

// Nerd Font glyph button: text color, highlight on hover, muted when disabled (Item.enabled also disables the MouseArea).
Text {
    id: btn
    signal clicked()
    property color baseColor: Theme.text
    color: !enabled ? Theme.muted : area.containsMouse ? Theme.highlight : baseColor
    font.family: Theme.iconFont
    font.pixelSize: 15

    MouseArea {
        id: area
        anchors { fill: parent; margins: -4 }
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
