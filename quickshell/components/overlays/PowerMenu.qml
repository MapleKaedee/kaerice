import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Power menu. Keys: Left/Right to select, Enter to run, Esc to close.
// No single-letter hotkeys on purpose (stray presses).
Overlay {
    id: root
    property int current: 0

    readonly property var actions: [
        // icon = Nerd Font code point: lock, sign-out, moon, refresh, power
        { label: "Lock", icon: 0xf023, fn: () => Lock.lock() },
        { label: "Logout", icon: 0xf08b, cmd: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { label: "Suspend", icon: 0xf186, cmd: ["systemctl", "suspend"] },
        { label: "Reboot", icon: 0xf021, cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: 0xf011, cmd: ["systemctl", "poweroff"] },
    ]

    function run(i) {
        Ui.power = false;
        const a = root.actions[i];
        if (a.fn) a.fn(); else Quickshell.execDetached(a.cmd);
    }

    name: "power"
    color: Theme.scrim
    visible: Ui.power
    focusItem: keys
    onDismissed: Ui.power = false
    onVisibleChanged: if (visible) root.current = 0

    Item {
        id: keys
        Keys.onEscapePressed: root.dismissed()
        Keys.onLeftPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
        Keys.onRightPressed: root.current = (root.current + 1) % root.actions.length
        Keys.onReturnPressed: root.run(root.current)
        Keys.onEnterPressed: root.run(root.current)
    }

    Row {
        anchors.centerIn: parent
        spacing: 20

        Repeater {
            model: root.actions

            Card {
                id: btn
                required property var modelData
                required property int index
                readonly property bool selected: root.current === index
                width: 150
                height: 150
                offset: selected ? 8 : 5
                fill: selected ? Theme.accent : Theme.paper

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String.fromCodePoint(btn.modelData.icon)
                        color: btn.selected ? Theme.paper : Theme.ink
                        font.family: Theme.iconFont
                        font.pixelSize: 44
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.modelData.label
                        color: btn.selected ? Theme.paper : Theme.ink
                        font.pixelSize: 20; font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.current = btn.index
                    onClicked: root.run(btn.index)
                }
            }
        }
    }
}
