import QtQuick
import qs.config
import qs.services
import qs.components.base

// Network status; click opens the Wi-Fi menu.
TextCard {
    readonly property bool offline: Network.kind === "offline"
    readonly property bool unavailable: Network.kind === "unavailable"
    text: Network.label
    // Nerd Font glyphs: ethernet port, wifi off, wifi
    icon: String.fromCodePoint(Network.kind === "eth" ? 0xf0200 : Network.online ? 0xf1eb : 0xf05aa)
    fill: offline ? Theme.text : Theme.face
    textColor: offline ? Theme.face : unavailable ? Theme.muted : Theme.text

    MouseArea { anchors.fill: parent; onClicked: Ui.wifi = !Ui.wifi }
}
