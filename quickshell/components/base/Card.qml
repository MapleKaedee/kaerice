import QtQuick
import qs.config

// Neo-brutal card: face with thick border + hard shadow offset to bottom-right.
// Children are placed inside the face.
Item {
    id: root
    property color fill: Theme.paper
    property color ink: Theme.ink
    property int offset: Theme.shadow
    default property alias content: face.data

    Rectangle {
        x: root.offset; y: root.offset
        width: root.width - root.offset
        height: root.height - root.offset
        radius: Theme.radius
        color: root.ink
    }
    Rectangle {
        id: face
        width: root.width - root.offset
        height: root.height - root.offset
        radius: Theme.radius
        color: root.fill
        border.width: Theme.border
        border.color: root.ink
    }
}
