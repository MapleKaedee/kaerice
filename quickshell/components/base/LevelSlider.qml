import QtQuick
import qs.config

// Draggable level bar: bordered track, accent fill. value (0..1) in; moved(v) out on click, drag and scroll.
Rectangle {
    id: root
    property real value: 0
    property real step: 0.05 // per scroll
    signal moved(real v)

    height: 22
    radius: Theme.corner(6)
    color: Theme.face
    border.width: Theme.border; border.color: Theme.line

    Rectangle {
        x: Theme.border; y: Theme.border
        height: parent.height - 2 * Theme.border
        width: Math.max(0, (parent.width - 2 * Theme.border) * Math.min(1, Math.max(0, root.value)))
        radius: Math.max(0, parent.radius - Theme.border)
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        function pick(mx) { root.moved(Math.max(0, Math.min(1, (mx - Theme.border) / (width - 2 * Theme.border)))); }
        onPressed: mouse => pick(mouse.x)
        onPositionChanged: mouse => { if (pressed) pick(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
