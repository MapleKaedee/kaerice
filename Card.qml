import QtQuick

// Neo-brutal card: face with thick border + hard shadow offset to bottom-right.
// Children are placed inside the face.
Item {
    id: root
    property color fill: "#f2f0eb"
    property color ink: "#1c1c1c"
    property int offset: 4
    default property alias content: face.data

    Rectangle {
        x: root.offset; y: root.offset
        width: root.width - root.offset
        height: root.height - root.offset
        radius: 8
        color: root.ink
    }
    Rectangle {
        id: face
        width: root.width - root.offset
        height: root.height - root.offset
        radius: 8
        color: root.fill
        border.width: 3
        border.color: root.ink
    }
}
