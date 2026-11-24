import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Power menu. Keys: Left/Right to select, Enter to run, Esc to close.
// No single-letter hotkeys on purpose (stray presses).
// With Session warnings (package manager, downloads), Logout / Reboot / Shutdown need a second press.
Overlay {
    id: root
    property int current: 0
    property int armed: -1 // risky action pressed once while warnings are shown

    readonly property var actions: [
        // icon = Nerd Font code point: lock, sign-out, moon, refresh, power
        { label: "Lock", icon: 0xf023, fn: () => Lock.lock() },
        { label: "Logout", icon: 0xf08b, risky: true, cmd: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { label: "Suspend", icon: 0xf186, cmd: ["systemctl", "suspend"] },
        { label: "Reboot", icon: 0xf021, risky: true, cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: 0xf011, risky: true, cmd: ["systemctl", "poweroff"] },
    ]

    function run(i) {
        const a = root.actions[i];
        if (a.risky && Session.warnings.length && root.armed !== i) { root.armed = i; return; }
        Ui.power = false;
        if (a.fn) a.fn(); else Quickshell.execDetached(a.cmd);
    }

    name: "power"
    color: Theme.scrim
    visible: Ui.power
    focusItem: keys
    onDismissed: Ui.power = false
    onVisibleChanged: if (visible) { root.current = 0; root.armed = -1; Session.refresh(); }

    Item {
        id: keys
        Keys.onEscapePressed: root.dismissed()
        Keys.onLeftPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
        Keys.onRightPressed: root.current = (root.current + 1) % root.actions.length
        Keys.onReturnPressed: root.run(root.current)
        Keys.onEnterPressed: root.run(root.current)
    }

    Column {
        anchors.centerIn: parent
        spacing: 30

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
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

        // warnings; after a first press on a risky action, also how to go on
        Card {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Session.warnings.length > 0
            width: warn.implicitWidth + 40 + offset
            height: warn.implicitHeight + 28 + offset
            offset: 5
            fill: Theme.accent
            Column {
                id: warn
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: Session.warnings
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Nerd Font triangle-exclamation f071
                        text: String.fromCodePoint(0xf071) + "  " + modelData
                        color: Theme.paper
                        font.pixelSize: 16; font.bold: true
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.armed >= 0
                    text: "Press " + (root.actions[root.armed]?.label ?? "") + " again to continue anyway"
                    color: Theme.ink
                    font.pixelSize: 15; font.bold: true
                }
            }
        }
    }
}
