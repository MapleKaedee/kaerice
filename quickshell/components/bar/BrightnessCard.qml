import QtQuick
import qs.config
import qs.services
import qs.components.base

// Screen backlight. Scroll = +/-5%.
TextCard {
    visible: Brightness.unavailable || Brightness.percent >= 0
    text: Brightness.unavailable ? "N/A" : Brightness.percent + "%"
    textColor: Brightness.unavailable ? Theme.muted : Theme.text
    icon: String.fromCodePoint(0xf185) // Nerd Font sun

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => Brightness.step(wheel.angleDelta.y > 0 ? 5 : -5)
    }
}
