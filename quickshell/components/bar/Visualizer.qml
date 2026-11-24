import QtQuick
import qs.config
import qs.services

// cava spectrum behind the bar cards, rising from the bar's bottom edge. Flat (hidden) when nothing plays.
Row {
    id: root
    property int maxHeight: 30
    readonly property int count: 64 // matches bars in config/cava.conf
    height: maxHeight
    spacing: 3

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: (root.width - (root.count - 1) * root.spacing) / root.count
            height: (Cava.bars[index] ?? 0) / 100 * root.maxHeight
            visible: height > 2
            radius: Theme.corner(2)
            color: Theme.accent
            border.width: Theme.stroke(2); border.color: Theme.line
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
