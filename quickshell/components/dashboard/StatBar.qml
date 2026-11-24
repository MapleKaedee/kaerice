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
        color: Theme.text
        font.family: Theme.iconFont; font.pixelSize: 16
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        text: root.label
        color: Theme.text
        font.pixelSize: 14; font.bold: true
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 22 - 44 - 96 - 3 * root.spacing
        height: 16
        radius: Theme.corner(4)
        color: Theme.face
        border.width: Theme.stroke(2); border.color: Theme.line
        Rectangle {
            x: parent.border.width; y: x
            height: parent.height - 2 * x
            width: Math.max(0, (parent.width - 2 * x) * Math.min(1, Math.max(0, root.value)))
            radius: Theme.corner(2)
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 96
        horizontalAlignment: Text.AlignRight
        text: root.detail
        color: Theme.text
        font.pixelSize: 13; font.bold: true
    }
}
