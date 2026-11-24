import QtQuick
import qs.config
import qs.services
import qs.components.base

// Emoji picker. Type to search (all words must match), arrows to move, Enter or click copies and closes,
// Esc closes. With an empty search, recently used emoji come first.
Overlay {
    id: root
    property string query: ""
    readonly property var results: query.trim() ? Emoji.search(query) : Emoji.recentItems.concat(Emoji.all)
    readonly property int columns: 10

    function pick(item) {
        if (!item) return;
        Ui.emoji = false;
        Emoji.pick(item.e);
    }

    name: "emoji"
    color: Theme.scrimLight
    visible: Ui.emoji
    focusItem: search
    onDismissed: Ui.emoji = false
    onVisibleChanged: {
        if (!visible) return;
        search.text = "";
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
    }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 560
        height: col.implicitHeight + 24 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Column {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 12

            Card {
                width: parent.width
                height: 50
                offset: Theme.depth(3)

                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                    onTextChanged: { root.query = text; grid.currentIndex = 0; }
                    Keys.onEscapePressed: root.dismissed()
                    Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                    Keys.onRightPressed: grid.moveCurrentIndexRight()
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onDownPressed: grid.moveCurrentIndexDown()
                    Keys.onReturnPressed: root.pick(root.results[grid.currentIndex])
                    Keys.onEnterPressed: root.pick(root.results[grid.currentIndex])

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search emoji…"
                        color: Theme.muted
                        font: search.font
                    }
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: cellHeight * 6
                cellWidth: width / root.columns
                cellHeight: 52
                clip: true
                model: root.results
                keyNavigationWraps: false

                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    width: grid.cellWidth - 4
                    height: grid.cellHeight - 4
                    radius: Theme.corner(6)
                    color: current ? Theme.accent : "transparent"
                    border.width: current ? Theme.border : 0
                    border.color: Theme.line

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.e
                        font.family: Theme.emojiFont
                        font.pixelSize: 28
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: grid.currentIndex = cell.index
                        onClicked: root.pick(cell.modelData)
                    }
                }
            }

            // name of the selected emoji, or why the grid is empty
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.results.length === 0 ? "No emoji found" : (root.results[grid.currentIndex]?.name ?? "")
                color: Theme.muted
                font.pixelSize: 14; font.bold: true
            }
        }
    }
}
