import QtQuick
import qs.services
import qs.components.base

// Screen backlight. Scroll = +/-5%.
TextCard {
    visible: Brightness.percent >= 0
    text: Brightness.percent + "%"
    icon: String.fromCodePoint(0xf185) // Nerd Font sun

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => Brightness.step(wheel.angleDelta.y > 0 ? 5 : -5)
    }
}
