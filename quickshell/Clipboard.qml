import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Clipboard history backed by cliphist. Open (SUPER+V): qs -c kaerice ipc call clipboard toggle
// Type to filter, Up/Down to select, Enter or click to copy it back (then paste with Ctrl+V),
// Shift+Delete or the x to remove an entry, Esc to close.
// Recording runs while this shell runs. cliphist skips content that password managers mark as sensitive,
// but anything else you copy is stored on disk (~/.cache/cliphist/db) until removed.
Scope {
    id: root
    property bool open: false
    property bool available: true
    property bool confirmWipe: false
    property string query: ""
    property var entries: []   // [{ line, id, text }] newest first

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q ? entries.filter(e => e.text.toLowerCase().includes(q)) : entries;
    }

    function refresh() { lister.running = true; }

    // the full "id<TAB>preview" line is what cliphist decode/delete expect on stdin
    function copy(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", e.line]);
        root.open = false;
    }

    function remove(e) {
        if (!e || del.running) return;
        del.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", e.line];
        del.running = true;
    }

    // records every clipboard change
    Process {
        running: true
        command: ["wl-paste", "--watch", "cliphist", "store"]
    }

    Process {
        id: lister
        command: ["sh", "-c", "exec cliphist list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.entries = listOut.text.split("\n").filter(l => l).map(l => {
                const tab = l.indexOf("\t");
                return { line: l, id: l.slice(0, tab), text: l.slice(tab + 1) };
            })
        }
        onExited: code => root.available = code !== 127
    }

    Process {
        id: del
        onExited: root.refresh()
    }

    Process {
        id: wipe
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open = !root.open; }
    }

    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#661c1c1c"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-clipboard"

        onVisibleChanged: {
            if (!visible) return;
            search.text = "";
            root.confirmWipe = false;
            list.currentIndex = 0;
            root.refresh();
            search.forceActiveFocus();
        }

        // click on the backdrop closes
        MouseArea { anchors.fill: parent; onClicked: root.open = false }

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
                            focus: true
                            color: "#1c1c1c"
                            font.pixelSize: 17; font.bold: true
                            onTextChanged: { root.query = text; list.currentIndex = 0; }
                            Keys.onEscapePressed: root.open = false
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onReturnPressed: root.copy(root.results[list.currentIndex])
                            Keys.onEnterPressed: root.copy(root.results[list.currentIndex])
                            Keys.onDeletePressed: event => {
                                if (event.modifiers & Qt.ShiftModifier) root.remove(root.results[list.currentIndex]);
                                else event.accepted = false;
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !search.text
                                text: String.fromCodePoint(0xf0ea) + "  Search clipboard…"
                                color: "#8c8680"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }
                        }
                    }

                    // clear all: first click arms, second click wipes
                    Card {
                        id: wipeButton
                        visible: root.entries.length > 0
                        width: root.confirmWipe ? 150 : 50
                        height: 50
                        offset: 3
                        fill: root.confirmWipe ? "#e8335a" : "#f2f0eb"
                        Text {
                            anchors.centerIn: parent
                            text: root.confirmWipe ? "Clear all?" : String.fromCodePoint(0xf1f8)
                            color: root.confirmWipe ? "#f2f0eb" : "#1c1c1c"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.confirmWipe ? 14 : 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!root.confirmWipe) { root.confirmWipe = true; return; }
                                root.confirmWipe = false;
                                wipe.running = true;
                            }
                        }
                    }
                }

                Text {
                    visible: !root.available || root.results.length === 0
                    text: !root.available ? "cliphist is not installed: sudo pacman -S cliphist"
                        : root.entries.length === 0 ? "Clipboard history is empty" : "No match"
                    color: "#1c1c1c"
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
                        readonly property color fg: current ? "#f2f0eb" : "#1c1c1c"
                        width: list.width
                        height: 44
                        radius: 6
                        color: current ? "#e8335a" : "transparent"
                        border.width: current ? 3 : 0
                        border.color: "#1c1c1c"

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
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
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
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                            MouseArea {
                                anchors { fill: parent; margins: -8 }
                                onClicked: root.remove(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
