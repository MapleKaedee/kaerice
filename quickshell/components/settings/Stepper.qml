import QtQuick
import qs.config
import qs.components.base

// Step through a list of numbers: - value +. A value outside the list shows as it is and steps to its neighbours.
// Tab focuses it (accent border), Left/Right step.
Card {
    id: root
    property var values: [] // ascending
    property real value
    property var format: v => String(v)
    signal picked(real value)
    readonly property var lower: values.filter(v => v < value).pop()
    readonly property var higher: values.find(v => v > value)
    width: 180; height: 38; offset: Theme.depth(3)
    line: activeFocus ? Theme.accent : Theme.line
    activeFocusOnTab: true

    function pick(v) { if (v !== undefined) picked(v); }
    Keys.onLeftPressed: pick(lower)
    Keys.onRightPressed: pick(higher)

    component Button: IconButton {
        width: 42; height: parent.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    Button { // minus
        text: String.fromCodePoint(0xf068)
        enabled: root.lower !== undefined
        onClicked: root.pick(root.lower)
    }
    Text {
        anchors.centerIn: parent
        text: root.format(root.value)
        color: Theme.text
        font.pixelSize: 14; font.bold: true
    }
    Button { // plus
        anchors.right: parent.right
        text: String.fromCodePoint(0xf067)
        enabled: root.higher !== undefined
        onClicked: root.pick(root.higher)
    }
}
