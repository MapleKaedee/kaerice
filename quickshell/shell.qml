//@ pragma UseQApplication
// UseQApplication: required for tray right-click menus (platform menus); needs a qs restart
import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    SystemClock { id: clock; precision: SystemClock.Minutes }

    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 52
        color: "transparent"

        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            Repeater {
                model: Hyprland.workspaces
                Card {
                    required property HyprlandWorkspace modelData
                    width: 40; height: 38
                    fill: modelData.focused ? "#e8335a" : "#f2f0eb"
                    Text { anchors.centerIn: parent; text: modelData.id; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
                }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8

            Tray { barWindow: bar }
            Network { onClicked: wifiMenu.open = !wifiMenu.open }
            Volume {}
            Brightness {}
            Battery {}

            TextCard {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                icon: String.fromCodePoint(0xf017) // Nerd Font clock
                fill: "#e8335a"
                textColor: "#f2f0eb"
            }
        }
    }

    NotificationPopups {}
    Launcher {}
    PowerMenu {}
    WifiMenu { id: wifiMenu }
    Wallpaper {}
}
