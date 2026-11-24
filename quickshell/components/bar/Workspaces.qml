import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.components.base

// Hyprland workspaces as cards; the focused one is accent. Click to switch.
Row {
    spacing: 8

    Repeater {
        model: Hyprland.workspaces

        Card {
            required property HyprlandWorkspace modelData
            width: Theme.bar(40); height: Theme.bar(38); offset: Theme.bar(Theme.shadow)
            fill: modelData.focused ? Theme.accent : Theme.face
            Text { anchors.centerIn: parent; text: modelData.id; color: modelData.focused ? Theme.accentText : Theme.text; font.pixelSize: Theme.bar(12); font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
        }
    }
}
