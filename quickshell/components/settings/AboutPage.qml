import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Distro, versions, and the settings file with a reset (needs a second click within 2 s).
Column {
    id: root
    spacing: 12

    Row {
        spacing: 18
        Text {
            text: String.fromCodePoint(SystemInfo.logo)
            color: Theme.accent
            font.family: Theme.iconFont; font.pixelSize: 64
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: SystemInfo.distro
                color: Theme.ink
                font.pixelSize: 20; font.bold: true
            }
            Text {
                text: SysStats.host
                color: Theme.muted
                font.pixelSize: 13; font.bold: true
            }
        }
    }

    Repeater {
        model: [["Kernel", "kernel"], ["Hyprland", "hyprland"], ["Quickshell", "quickshell"], ["kaerice", "kaerice"]]
        Row {
            required property var modelData
            Text {
                width: 130
                text: parent.modelData[0]
                color: Theme.muted
                font.pixelSize: 14; font.bold: true
            }
            Text {
                text: SystemInfo.versions[parent.modelData[1]] || "--"
                color: Theme.ink
                font.pixelSize: 14; font.bold: true
            }
        }
    }

    Item { width: 1; height: 4 }
    Text {
        text: "Settings file"
        color: Theme.ink
        font.pixelSize: 15; font.bold: true
    }
    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: Settings.path.replace(Quickshell.env("HOME"), "~") + (Settings.changed ? "" : "  (all defaults)")
        color: Theme.muted
        font.pixelSize: 13; font.bold: true
    }
    TextButton { // rotate-left
        glyph: 0xf0e2
        label: arm.running ? "Sure? The old file goes to settings.json.bak" : "Reset all settings"
        hot: arm.running
        enabled: Settings.changed
        onClicked: {
            if (!arm.running) { arm.start(); return; }
            arm.stop();
            Settings.reset();
        }
        Timer { id: arm; interval: 2000 }
    }
}
