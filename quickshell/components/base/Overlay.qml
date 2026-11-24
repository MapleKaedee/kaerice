import Quickshell
import Quickshell.Wayland
import QtQuick

// Full-screen overlay layer with exclusive keyboard focus.
// Clicking the backdrop or pressing Esc emits dismissed(). When it opens, focusItem gets keyboard focus.
PanelWindow {
    id: root
    property string name: "overlay"   // layer namespace: kaerice-<name>
    property Item focusItem: keys
    signal dismissed()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "kaerice-" + name

    onVisibleChanged: if (visible) focusItem.forceActiveFocus()

    MouseArea { anchors.fill: parent; onClicked: root.dismissed() }

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: root.dismissed()
    }
}
