import QtQuick
import qs.config
import qs.services
import qs.components.base

// Distro logo. Click opens the control center.
Card {
    id: root
    width: Theme.bar(40) + offset; height: Theme.bar(38); offset: Theme.bar(Theme.shadow)
    fill: Ui.controlCenter ? Theme.accent : Theme.face

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(SystemInfo.logo)
        color: Ui.controlCenter ? Theme.accentText : Theme.text
        font.family: Theme.iconFont; font.pixelSize: Theme.bar(19)
    }

    MouseArea { anchors.fill: parent; onClicked: Ui.controlCenter = !Ui.controlCenter }
}
