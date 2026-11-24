import QtQuick
import qs.config

// One setting in a page Column: label and hint on the left, its control on the right.
Item {
    id: root
    property string label
    property string hint
    default property alias control: slot.data
    width: parent?.width ?? 0
    implicitHeight: Math.max(texts.implicitHeight, slot.height)

    Column {
        id: texts
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - (slot.width ? slot.width + 16 : 0)
        spacing: 2
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: root.label
            color: Theme.text
            font.pixelSize: 15; font.bold: true
        }
        Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: root.hint
            color: Theme.muted
            font.pixelSize: 12; font.bold: true
        }
    }
    Item {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
}
