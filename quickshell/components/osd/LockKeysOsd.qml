import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Caps Lock / Num Lock card at bottom center (same place as LevelOsd), accent while the lock is on.
// Takes no input or keyboard focus: clicks pass through.
PanelWindow {
    id: root
    readonly property bool caps: Osd.kind === "capsLock"

    visible: Osd.shown && (caps || Osd.kind === "numLock")
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
        readonly property color text: LockKeys.on ? Theme.paper : Theme.ink
        width: 240
        height: 64
        offset: 6
        fill: LockKeys.on ? Theme.accent : Theme.paper

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Nerd Font: caps arrow f0632, numeric f03a0
                text: String.fromCodePoint(root.caps ? 0xf0632 : 0xf03a0)
                color: card.text
                font.family: Theme.iconFont; font.pixelSize: 24
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.caps ? "Caps Lock " : "Num Lock ") + (LockKeys.on ? "ON" : "OFF")
                color: card.text
                font.pixelSize: 16; font.bold: true
            }
        }
    }
}
