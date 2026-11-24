import QtQuick
import qs.config

// Small glyph button in the corner of a thumbnail. hot = accent (armed), busy = turning.
Rectangle {
    id: root
    property int glyph
    property bool hot: false
    property bool busy: false
    signal clicked()
    width: 32; height: 32
    radius: Theme.corner(6)
    color: hot ? Theme.accent : area.containsMouse ? Theme.hover : Theme.face
    border.width: Theme.stroke(2); border.color: Theme.line

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(root.glyph)
        color: root.hot ? Theme.accentText : Theme.text
        font.family: Theme.iconFont; font.pixelSize: 15
        RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite; onRunningChanged: if (!running) icon.rotation = 0 }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
