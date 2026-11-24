import QtQuick
import qs.config

// Label, level bar (accent fill), value text. value: 0..1, or < 0 for "--".
Row {
    id: root
    property string label
    property int glyph
    property real value: 0
    property string detail: value < 0 ? "--" : Math.round(value * 100) + "%"
    spacing: 12

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        text: String.fromCodePoint(root.glyph)
        color: Theme.ink
        font.family: Theme.iconFont; font.pixelSize: 16
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        text: root.label
        color: Theme.ink
        font.pixelSize: 14; font.bold: true
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 22 - 44 - 96 - 3 * root.spacing
        height: 16
        radius: 4
        color: Theme.paper
        border.width: 2; border.color: Theme.ink
        Rectangle {
            x: 2; y: 2
            height: parent.height - 4
            width: Math.max(0, (parent.width - 4) * Math.min(1, Math.max(0, root.value)))
            radius: 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 96
        horizontalAlignment: Text.AlignRight
        text: root.detail
        color: Theme.ink
        font.pixelSize: 13; font.bold: true
    }
}
