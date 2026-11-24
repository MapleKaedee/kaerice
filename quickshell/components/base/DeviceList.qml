import QtQuick
import qs.config
import qs.services

// Audio devices to choose from: one row each, the one in use filled.
// Tab focuses a row (accent border); Enter, Space or a click picks it.
Column {
    id: root
    property var nodes: []
    property var current
    property int glyph
    signal picked(var node)
    width: parent?.width ?? 0
    spacing: 8

    Text {
        visible: root.nodes.length === 0
        text: "No device"
        color: Theme.muted
        font.pixelSize: 13; font.bold: true
    }
    Repeater {
        model: root.nodes
        Card {
            id: row
            required property var modelData
            readonly property bool active: modelData === root.current
            width: root.width; height: 52; offset: 3
            fill: active ? Theme.accent : area.containsMouse ? Theme.hover : Theme.paper
            ink: activeFocus ? Theme.accent : Theme.ink
            activeFocusOnTab: true
            Keys.onReturnPressed: root.picked(modelData)
            Keys.onEnterPressed: root.picked(modelData)
            Keys.onSpacePressed: root.picked(modelData)

            Text {
                id: icon
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 26
                horizontalAlignment: Text.AlignHCenter
                text: String.fromCodePoint(root.glyph)
                color: row.active ? Theme.paper : Theme.ink
                font.family: Theme.iconFont; font.pixelSize: 17
            }
            Column {
                anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Audio.deviceName(row.modelData)
                    color: row.active ? Theme.paper : Theme.ink
                    font.pixelSize: 13; font.bold: true
                }
                Text {
                    text: row.active ? "Active" : "Available"
                    color: row.active ? Theme.paper : Theme.muted
                    font.pixelSize: 11; font.bold: true
                }
            }
            MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.picked(row.modelData) }
        }
    }
}
