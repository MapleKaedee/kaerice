import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Volume/brightness level card at bottom center. Shown via the osd IPC (media keys).
// Takes no input or keyboard focus: clicks pass through.
PanelWindow {
    id: root
    readonly property bool isVolume: Osd.kind === "volume"
    readonly property bool muted: isVolume && Audio.muted
    readonly property bool unknown: !isVolume && Brightness.percent < 0
    readonly property int percent: Math.max(0, Math.min(100, isVolume ? Audio.percent : Brightness.percent))

    visible: Osd.shown && (isVolume || Osd.kind === "brightness")
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kaerice-osd"

    Card {
        id: card
        width: 340
        height: 64

        Row {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 14

            Text {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                // Nerd Font glyphs: speaker off / low / high, sun
                text: String.fromCodePoint(!root.isVolume ? 0xf185
                    : root.muted ? 0xf026 : root.percent < 50 ? 0xf027 : 0xf028)
                color: Theme.text
                font.family: Theme.iconFont
                font.pixelSize: 20
            }

            // level bar
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - icon.width - value.width - 2 * parent.spacing
                height: 18
                radius: Theme.corner(4)
                color: Theme.face
                border.width: Theme.border
                border.color: Theme.line

                Rectangle {
                    x: Theme.border
                    y: Theme.border
                    height: parent.height - 2 * Theme.border
                    width: (parent.width - 2 * Theme.border) * (root.muted ? 0 : root.percent / 100)
                    radius: Theme.corner(2)
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Text {
                id: value
                anchors.verticalCenter: parent.verticalCenter
                width: 52 // fixed so the bar doesn't jump as digits change
                horizontalAlignment: Text.AlignRight
                text: root.unknown ? "N/A" : root.muted ? "MUTE" : root.percent + "%"
                color: Theme.text
                font.pixelSize: 15; font.bold: true
            }
        }
    }
}
