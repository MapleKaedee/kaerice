import QtQuick
import qs.config
import qs.components.base

// Pick one of a few values: a row of cells, the current one filled. An option with a color is a swatch, checked when current.
// Tab focuses it (accent border), Left/Right change it, a click picks.
Card {
    id: root
    property var options: [{ value: false, label: "Off" }, { value: true, label: "On" }]
    property var value
    signal picked(var value)
    width: row.width + 2 * Theme.border + offset; height: 38; offset: Theme.depth(3)
    line: activeFocus ? Theme.accent : Theme.line
    activeFocusOnTab: true

    function move(delta) {
        const to = options[options.findIndex(o => o.value === value) + delta];
        if (to) picked(to.value);
    }
    Keys.onLeftPressed: move(-1)
    Keys.onRightPressed: move(1)

    Row {
        id: row
        x: Theme.border; y: Theme.border
        height: parent.height - 2 * Theme.border
        Repeater {
            model: root.options
            Rectangle {
                id: cell
                required property var modelData
                readonly property bool selected: modelData.value === root.value
                width: Math.max(46, label.implicitWidth + 24); height: row.height
                radius: Math.max(0, Theme.radius - Theme.border)
                color: modelData.color ?? (selected ? Theme.accent : area.containsMouse ? Theme.hover : "transparent")
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: cell.modelData.color && cell.selected ? "✓" : cell.modelData.label
                    color: cell.modelData.color ? Theme.textOn(cell.modelData.color) : cell.selected ? Theme.accentText : Theme.text
                    font.pixelSize: 13; font.bold: true
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.picked(cell.modelData.value) }
            }
        }
    }
}
