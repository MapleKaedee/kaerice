import QtQuick
import qs.config
import qs.services
import qs.components.base

// Default output volume. Scroll changes it, click = mute toggle.
TextCard {
    visible: !!Audio.sink
    text: Audio.muted ? "MUTE" : Audio.percent + "%"
    // Nerd Font glyphs: speaker off / low / high
    icon: String.fromCodePoint(Audio.muted ? 0xf026 : Audio.percent < 50 ? 0xf027 : 0xf028)
    fill: Audio.muted ? Theme.text : Theme.face
    textColor: Audio.muted ? Theme.face : Theme.text

    MouseArea {
        anchors.fill: parent
        onClicked: Audio.toggleMute()
        onWheel: wheel => Audio.step(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
