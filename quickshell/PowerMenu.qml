import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Power menu. Toggle: qs -c kaerice ipc call power toggle
// Keys: Left/Right to select, Enter to run, Esc to close. No single-letter hotkeys on purpose (stray presses).
Scope {
    id: root
    property bool open: false
    property int current: 0

    readonly property var actions: [
        { label: "Logout", icon: "system-log-out", cmd: ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { label: "Suspend", icon: "system-suspend", cmd: ["systemctl", "suspend"] },
        { label: "Reboot", icon: "system-reboot", cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", icon: "system-shutdown", cmd: ["systemctl", "poweroff"] },
    ]

    function run(i) {
        root.open = false;
        Quickshell.execDetached(root.actions[i].cmd);
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.open = !root.open; }
    }

    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#991c1c1c"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-power"

        onVisibleChanged: {
            if (!visible) return;
            root.current = 0;
            keys.forceActiveFocus();
        }

        // click on the backdrop closes
        MouseArea { anchors.fill: parent; onClicked: root.open = false }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.open = false
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
                    fill: selected ? "#e8335a" : "#f2f0eb"

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 40
                            source: Quickshell.iconPath(btn.modelData.icon, true)
                            visible: source != ""
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.label
                            color: btn.selected ? "#f2f0eb" : "#1c1c1c"
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
}
