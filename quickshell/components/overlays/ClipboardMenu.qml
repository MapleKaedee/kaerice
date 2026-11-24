import QtQuick
import qs.config
import qs.services
import qs.components.base

// Clipboard history (cliphist). Type to filter, Up/Down to select, Enter or click to copy it back
// (then paste with Ctrl+V), Shift+Delete or the x to remove an entry, Esc to close.
Overlay {
    id: root
    property bool confirmWipe: false
    property string query: ""

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q ? Clipboard.entries.filter(e => e.text.toLowerCase().includes(q)) : Clipboard.entries;
    }

    function copy(e) {
        if (!e) return;
        Clipboard.copy(e);
        Ui.clipboard = false;
    }

    name: "clipboard"
    color: Theme.scrimLight
    visible: Ui.clipboard
    focusItem: search
    onDismissed: Ui.clipboard = false
    onVisibleChanged: {
        if (!visible) return;
        search.text = "";
        root.confirmWipe = false;
        list.currentIndex = 0;
        Clipboard.refresh();
    }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.15
        width: 620
        height: col.implicitHeight + 24 + offset
        offset: 6

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Column {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                Card {
                    width: parent.width - wipeButton.width - 10
                    height: 50
                    offset: 3

                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.ink
                        font.pixelSize: 17; font.bold: true
                        onTextChanged: { root.query = text; list.currentIndex = 0; }
                        Keys.onEscapePressed: root.dismissed()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onReturnPressed: root.copy(root.results[list.currentIndex])
                        Keys.onEnterPressed: root.copy(root.results[list.currentIndex])
                        Keys.onDeletePressed: event => {
                            if (event.modifiers & Qt.ShiftModifier) Clipboard.remove(root.results[list.currentIndex]);
                            else event.accepted = false;
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: String.fromCodePoint(0xf0ea) + "  Search clipboard…"
                            color: Theme.muted
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                        }
                    }
                }

                // clear all: first click arms, second click wipes
                Card {
                    id: wipeButton
                    visible: Clipboard.entries.length > 0
                    width: root.confirmWipe ? 150 : 50
                    height: 50
                    offset: 3
                    fill: root.confirmWipe ? Theme.accent : Theme.paper
                    Text {
                        anchors.centerIn: parent
                        text: root.confirmWipe ? "Clear all?" : String.fromCodePoint(0xf1f8)
                        color: root.confirmWipe ? Theme.paper : Theme.ink
                        font.family: Theme.iconFont
                        font.pixelSize: root.confirmWipe ? 14 : 18
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!root.confirmWipe) { root.confirmWipe = true; return; }
                            root.confirmWipe = false;
                            Clipboard.wipe();
                        }
                    }
                }
            }

            Text {
                visible: !Clipboard.available || root.results.length === 0
                text: !Clipboard.available ? "cliphist is not installed: sudo pacman -S cliphist"
                    : Clipboard.entries.length === 0 ? "Clipboard history is empty" : "No match"
                color: Theme.ink
                opacity: 0.75
                font.pixelSize: 13
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(count, 9) * 44
                visible: count > 0
                clip: true
                model: root.results
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool binary: modelData.text.startsWith("[[ binary data")
                    readonly property color fg: current ? Theme.paper : Theme.ink
                    width: list.width
                    height: 44
                    radius: 6
                    color: current ? Theme.accent : "transparent"
                    border.width: current ? Theme.border : 0
                    border.color: Theme.ink

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: root.copy(row.modelData)
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.binary
                            text: String.fromCodePoint(0xf03e) // image
                            color: row.fg
                            font.family: Theme.iconFont; font.pixelSize: 15
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: list.width - 70
                            text: row.modelData.text.replace(/\s+/g, " ")
                            elide: Text.ElideRight
                            color: row.fg
                            font.pixelSize: 14; font.bold: row.current
                        }
                    }

                    Text {
                        visible: row.current
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(0xf00d) // x
                        color: row.fg
                        font.family: Theme.iconFont; font.pixelSize: 15
                        MouseArea {
                            anchors { fill: parent; margins: -8 }
                            onClicked: Clipboard.remove(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
