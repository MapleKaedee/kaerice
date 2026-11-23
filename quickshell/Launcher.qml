import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// App launcher. Toggle: qs -c kaerice ipc call launcher toggle
// Keys: type to filter, Up/Down to select, Enter to launch, Esc to close.
Scope {
    id: root
    property bool open: false
    property string query: ""

    // shortcut: plain substring match over name/genericName/keywords; upgrade to fuzzy scoring if results feel off
    readonly property var results: {
        const q = query.trim().toLowerCase();
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay)
            .filter(a => !q || (a.name + " " + a.genericName + " " + a.keywords.join(" ")).toLowerCase().includes(q))
            .sort((a, b) => {
                const as = a.name.toLowerCase().startsWith(q);
                const bs = b.name.toLowerCase().startsWith(q);
                return as === bs ? a.name.localeCompare(b.name) : (as ? -1 : 1);
            });
    }

    function launch(entry) {
        if (!entry) return;
        root.open = false;
        entry.execute();
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open = !root.open; }
    }

    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#661c1c1c"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-launcher"

        onVisibleChanged: {
            if (!visible) return;
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }

        // click on the backdrop closes
        MouseArea { anchors.fill: parent; onClicked: root.open = false }

        Card {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            width: 560
            height: col.implicitHeight + 24 + offset
            offset: 6

            MouseArea { anchors.fill: parent } // swallow clicks inside the card

            Column {
                id: col
                x: 12; y: 12
                width: parent.width - 24
                spacing: 12

                Card {
                    width: parent.width
                    height: 50
                    offset: 3

                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        color: "#1c1c1c"
                        font.pixelSize: 18; font.bold: true
                        onTextChanged: { root.query = text; list.currentIndex = 0; }
                        Keys.onEscapePressed: root.open = false
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onReturnPressed: root.launch(root.results[list.currentIndex])
                        Keys.onEnterPressed: root.launch(root.results[list.currentIndex])

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: "Search apps…"
                            color: "#8c8680"
                            font: search.font
                        }
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: Math.min(count, 8) * 46
                    visible: count > 0
                    clip: true
                    model: root.results
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem
                        width: list.width
                        height: 46
                        radius: 6
                        color: current ? "#e8335a" : "transparent"
                        border.width: current ? 3 : 0
                        border.color: "#1c1c1c"

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 26
                                source: Quickshell.iconPath(row.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name
                                color: row.current ? "#f2f0eb" : "#1c1c1c"
                                font.pixelSize: 15; font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: root.launch(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
