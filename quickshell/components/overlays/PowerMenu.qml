import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Power menu. Keys: Left/Right to select, hold Enter (or the mouse button) to run, Esc to close.
// No single-letter hotkeys on purpose (stray presses).
// Hold time: settings "power.hold"; Logout / Reboot / Shutdown take 2 s longer while Session warns (package
// manager, downloads). Lock needs no hold.
Overlay {
    id: root
    property int current: 0
    property int holding: -1    // action being held
    property real progress: 0   // 0..1 of its hold time
    readonly property bool warned: Session.warnings.length > 0

    readonly property var actions: [
        // icon = Nerd Font code point: lock, sign-out, moon, refresh, power
        { label: "Lock", icon: 0xf023, fn: () => Lock.lock() },
        { label: "Logout", icon: 0xf08b, hold: true, risky: true, cmd: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { label: "Suspend", icon: 0xf186, hold: true, cmd: ["systemctl", "suspend"] },
        { label: "Reboot", icon: 0xf021, hold: true, risky: true, cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: 0xf011, hold: true, risky: true, cmd: ["systemctl", "poweroff"] },
    ]

    function holdMs(i) {
        const a = root.actions[i];
        return (a.hold ? Settings.get("power.hold") : 0) + (a.risky && root.warned ? 2000 : 0);
    }
    function press(i) {
        if (holdMs(i) === 0) { run(i); return; }
        hold.duration = holdMs(i);
        root.holding = i;
        hold.restart();
    }
    function release() {
        hold.stop();
        root.holding = -1;
        root.progress = 0;
    }
    function run(i) {
        const a = root.actions[i];
        release();
        Ui.power = false;
        if (a.fn) a.fn(); else Quickshell.execDetached(a.cmd);
    }

    name: "power"
    color: Theme.scrim
    visible: Ui.power
    focusItem: keys
    onDismissed: Ui.power = false
    onVisibleChanged: { release(); if (visible) { root.current = 0; Session.refresh(); } }
    onCurrentChanged: release()
    onWarnedChanged: release() // a warning that shows up mid-hold must be read first

    NumberAnimation { id: hold; target: root; property: "progress"; from: 0; to: 1; onFinished: root.run(root.holding) }

    Item {
        id: keys
        Keys.onEscapePressed: root.dismissed()
        Keys.onLeftPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
        Keys.onRightPressed: root.current = (root.current + 1) % root.actions.length
        Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.press(root.current); }
        Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.press(root.current); }
        Keys.onReleased: event => {
            if (!event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) root.release();
        }
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

                    Rectangle { // hold progress, filling up from the bottom
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.border }
                        height: (parent.height - 2 * Theme.border) * root.progress
                        visible: root.holding === btn.index
                        radius: Math.max(0, Theme.radius - Theme.border)
                        color: Theme.ink
                    }

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
                        onPressed: if (root.holdMs(btn.index) > 0) root.press(btn.index)
                        onReleased: root.release()
                        onCanceled: root.release()
                        onExited: root.release()
                        onClicked: if (root.holdMs(btn.index) === 0) root.run(btn.index)
                    }
                }
            }
        }

        // how to confirm the selected action; keeps its space so the row does not jump
        Card {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.holdMs(root.current) > 0 ? 1 : 0
            width: hint.implicitWidth + 32 + offset
            height: 40
            Text {
                id: hint
                anchors.centerIn: parent
                text: "Hold Enter or the mouse button for " + root.holdMs(root.current) / 1000 + " s"
                color: Theme.ink
                font.pixelSize: 14; font.bold: true
            }
        }

        Card {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.warned
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
            }
        }
    }
}
