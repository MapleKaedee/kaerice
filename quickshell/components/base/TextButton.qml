import QtQuick
import qs.config

// Small button card: Nerd Font glyph + label. hot = accent (armed or primary); muted while disabled.
// Tab focuses it (accent border), Enter or Space presses it.
Card {
    id: root
    property int glyph
    property string label
    property bool hot: false
    signal clicked()
    width: row.implicitWidth + 24 + offset; height: 38; offset: Theme.depth(3)
    fill: hot ? Theme.accent : Theme.face
    line: activeFocus ? Theme.accent : Theme.line
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(root.glyph)
            color: root.hot ? Theme.accentText : Theme.text
            font.family: Theme.iconFont; font.pixelSize: 15
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.hot ? Theme.accentText : Theme.text
            font.pixelSize: 13; font.bold: true
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
