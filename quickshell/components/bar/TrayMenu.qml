import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Menu of a tray icon, at the bar next to it. Not the platform's menu: Quickshell 0.3.2 crashes when an app exits while
// its platform menu is open. Up/Down and Enter, Right and Left go into and out of a submenu, Esc or a click outside closes.
Overlay {
    id: root
    name: "tray-menu"
    property SystemTrayItem item: null // whose menu is open; null = closed (also when its app exits)
    property real iconX: 0
    property var path: []              // submenus entered, outermost first
    readonly property var model: path.length ? sub.children : top.children
    readonly property var entries: model?.values ?? []

    visible: item !== null
    focusItem: list
    onDismissed: item = null
    onItemChanged: path = []

    function open(trayItem, x) { iconX = x; item = trayItem; }
    function move(by) {
        for (let i = list.currentIndex + by; i >= 0 && i < entries.length; i += by)
            if (!entries[i].isSeparator && entries[i].enabled) { list.currentIndex = i; return; }
    }
    function back() { if (path.length) path = path.slice(0, -1); }
    function trigger(entry) {
        if (!entry || entry.isSeparator || !entry.enabled) return;
        if (entry.hasChildren) { path = path.concat([entry]); return; }
        entry.triggered();
        item = null;
    }

    // two, because the main menu must stay open while a submenu shows: without a reference its entries are dropped
    QsMenuOpener { id: top; menu: root.item?.menu ?? null }
    QsMenuOpener { id: sub; menu: root.path[root.path.length - 1] ?? null }

    Card {
        x: Math.max(14, Math.min(root.iconX, parent.width - width - 14))
        y: BarLayout.panelY(height, parent.height)
        width: 280
        height: col.implicitHeight + 16 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the menu

        Column {
            id: col
            x: 8; y: 8
            width: parent.width - 16

            Rectangle { // back to the menu above
                visible: root.path.length > 0
                width: parent.width; height: 36
                radius: Theme.corner(6)
                color: backArea.containsMouse ? Theme.hover : "transparent"
                Text {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: String.fromCodePoint(0xf053) + "  " + (root.path[root.path.length - 1]?.text ?? "") // chevron-left
                    color: Theme.muted
                    font.family: Theme.iconFont; font.pixelSize: 14; font.bold: true
                }
                MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.back() }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, root.height - BarLayout.height - 120)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                highlightMoveDuration: 0
                model: root.model

                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onReturnPressed: root.trigger(root.entries[currentIndex])
                Keys.onEnterPressed: root.trigger(root.entries[currentIndex])
                Keys.onRightPressed: if (root.entries[currentIndex]?.hasChildren) root.trigger(root.entries[currentIndex])
                Keys.onLeftPressed: root.back()
                Keys.onEscapePressed: root.dismissed()

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool separator: modelData?.isSeparator ?? false
                    readonly property bool usable: !separator && (modelData?.enabled ?? false)
                    readonly property bool current: usable && ListView.isCurrentItem
                    readonly property color fg: !usable ? Theme.muted : current ? Theme.accentText : Theme.text
                    readonly property bool checkable: (modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                    width: list.width; height: separator ? 13 : 36
                    radius: Theme.corner(6)
                    color: current ? Theme.accent : "transparent"

                    Rectangle {
                        visible: row.separator
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                        height: Theme.stroke(2)
                        color: Theme.line
                        opacity: 0.4
                    }
                    Row {
                        visible: !row.separator
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Text {
                            id: check
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.checkable
                            // Nerd Font: circle with / without dot, square with / without check
                            text: String.fromCodePoint(row.modelData?.buttonType === QsMenuButtonType.RadioButton
                                ? (row.modelData?.checkState === Qt.Checked ? 0xf192 : 0xf10c) : (row.modelData?.checkState === Qt.Checked ? 0xf046 : 0xf096))
                            color: row.fg
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        IconImage {
                            id: icon
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!row.modelData?.icon
                            implicitSize: 18
                            source: row.modelData?.icon ?? ""
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 20 - (check.visible ? check.width + 10 : 0) - (icon.visible ? 28 : 0) - (more.visible ? 20 : 0)
                            elide: Text.ElideRight
                            text: row.modelData?.text ?? ""
                            color: row.fg
                            font.pixelSize: 14; font.bold: true
                        }
                    }
                    Text {
                        id: more
                        visible: row.modelData?.hasChildren ?? false
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(0xf054) // chevron-right
                        color: row.fg
                        font.family: Theme.iconFont; font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (row.usable) list.currentIndex = row.index
                        onClicked: root.trigger(row.modelData)
                    }
                }
            }
        }
    }
}
