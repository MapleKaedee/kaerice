import Quickshell.WindowManager
import QtQuick
import qs.config
import qs.components.base

// Workspaces (Mango: tags) as cards; the active one is accent. Click to switch.
Row {
    spacing: 8

    Repeater {
        // Mango lists all 9 tags, empty ones without shouldDisplay; named workspaces sort before numbers.
        // The Hyprland scratchpad by name, not by id: named workspaces are negative too.
        model: WindowManager.windowsets
            .filter(w => w.shouldDisplay && !w.name.startsWith("special:"))
            .sort((a, b) => (parseInt(a.name) || 0) - (parseInt(b.name) || 0))

        Card {
            required property Windowset modelData
            width: Theme.bar(40); height: Theme.bar(38); offset: Theme.bar(Theme.shadow)
            fill: modelData.active ? Theme.accent : Theme.face
            Text { anchors.centerIn: parent; text: modelData.name; color: modelData.active ? Theme.accentText : Theme.text; font.pixelSize: Theme.bar(12); font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
        }
    }
}
