import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components.greeter

// The login screen, a second entry point next to shell.qml. greetd starts it through greeter/start.sh
// as the user "greeter", from the copy that install-greeter.sh makes.
ShellRoot {
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.ink
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-greeter"

        GreeterSurface {}
    }
}
