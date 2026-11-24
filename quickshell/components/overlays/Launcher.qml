import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// App launcher. Keys: type to filter, Up/Down to select, Enter to launch, Esc to close.
Overlay {
    id: root
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
        Ui.launcher = false;
        entry.execute();
    }

    name: "launcher"
    color: Theme.scrimLight
    visible: Ui.launcher
    focusItem: search
    onDismissed: Ui.launcher = false
    onVisibleChanged: {
        if (!visible) return;
        search.text = "";
        list.currentIndex = 0;
    }

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
                    color: Theme.ink
                    font.pixelSize: 18; font.bold: true
                    onTextChanged: { root.query = text; list.currentIndex = 0; }
                    Keys.onEscapePressed: root.dismissed()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onReturnPressed: root.launch(root.results[list.currentIndex])
                    Keys.onEnterPressed: root.launch(root.results[list.currentIndex])

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search apps…"
                        color: Theme.muted
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
                    color: current ? Theme.accent : "transparent"
                    border.width: current ? Theme.border : 0
                    border.color: Theme.ink

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
                            color: row.current ? Theme.paper : Theme.ink
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
