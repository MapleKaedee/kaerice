import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Settings: menu on the left, page on the right. No scrim and never over the bar, so changes show at once.
// Keys: Up/Down switch pages, Tab reaches the controls, Left/Right change the focused one, Esc closes. Add a page: one line in `pages` + a Component.
Overlay {
    id: root
    name: "settings"
    exclusionMode: ExclusionMode.Normal // leaves the bar's space free
    visible: Ui.settings
    focusItem: panel
    onDismissed: Ui.settings = false
    onVisibleChanged: if (visible) { Account.refresh(); SystemInfo.refresh(); }

    property int current: 0
    // icon: Nerd Font music f001, power f011, bell f0f3, user f007, circle-info f05a
    readonly property var pages: [
        { title: "Sound & media", icon: 0xf001, page: sound },
        { title: "Power", icon: 0xf011, page: power },
        { title: "Notifications", icon: 0xf0f3, page: notifications },
        { title: "Users & accounts", icon: 0xf007, page: users },
        { title: "About", icon: 0xf05a, page: about }
    ]
    Component { id: sound; SoundPage {} }
    Component { id: power; PowerPage {} }
    Component { id: notifications; NotificationsPage {} }
    Component { id: users; UsersPage {} }
    Component { id: about; AboutPage {} }

    function move(delta) { current = (current + delta + pages.length) % pages.length; }

    Card {
        id: panel
        // on the panel itself, so keys a focused text field does not use still arrive here
        Keys.onEscapePressed: root.dismissed()
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        anchors.centerIn: parent
        width: Math.min(860, parent.width - 60)
        height: Math.min(560, parent.height - 60)
        offset: 8

        MouseArea { anchors.fill: parent } // swallow clicks inside the panel

        // menu
        Column {
            id: nav
            x: 14; y: 14
            width: 210
            spacing: 6

            Text {
                height: 44
                leftPadding: 10
                verticalAlignment: Text.AlignVCenter
                text: "Settings"
                color: Theme.ink
                font.pixelSize: 22; font.bold: true
            }

            Repeater {
                model: root.pages
                Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.current === index
                    width: nav.width; height: 42
                    radius: 6
                    color: selected ? Theme.accent : area.containsMouse ? Theme.hover : "transparent"
                    border.width: selected ? Theme.border : 0
                    border.color: Theme.ink
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: String.fromCodePoint(item.modelData.icon)
                            color: item.selected ? Theme.paper : Theme.ink
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData.title
                            color: item.selected ? Theme.paper : Theme.ink
                            font.pixelSize: 14; font.bold: true
                        }
                    }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: { root.current = item.index; panel.forceActiveFocus(); } }
                }
            }
        }

        Rectangle { // divider
            anchors { left: nav.right; leftMargin: 14; top: parent.top; bottom: parent.bottom }
            width: Theme.border
            color: Theme.ink
        }

        // page
        Item {
            anchors { left: nav.right; leftMargin: 14 + Theme.border; right: parent.right; top: parent.top; bottom: parent.bottom }

            Text {
                id: title
                x: 22; y: 14
                height: 44
                verticalAlignment: Text.AlignVCenter
                text: root.pages[root.current].title
                color: Theme.ink
                font.pixelSize: 22; font.bold: true
            }
            IconButton {
                anchors { right: parent.right; rightMargin: 24; verticalCenter: title.verticalCenter }
                text: String.fromCodePoint(0xf00d) // xmark
                font.pixelSize: 18
                onClicked: root.dismissed()
            }

            Flickable {
                id: flick
                anchors { left: parent.left; leftMargin: 22; right: parent.right; rightMargin: 22; top: title.bottom; topMargin: 10; bottom: parent.bottom; bottomMargin: 16 }
                contentHeight: page.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Loader {
                    id: page
                    width: flick.width
                    active: root.visible
                    sourceComponent: root.pages[root.current].page
                }
            }
        }
    }
}
