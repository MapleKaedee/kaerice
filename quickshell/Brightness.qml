import Quickshell
import Quickshell.Io
import QtQuick

// Screen backlight via brightnessctl. Scroll = +/-5% (never below 1% so the screen can't go black).
// shortcut: sysfs backlight gives no reliable change events, so it polls every 2 s; scroll updates instantly.
TextCard {
    id: root
    property int percent: -1

    visible: percent >= 0
    text: percent + "%"
    icon: String.fromCodePoint(0xf185) // Nerd Font sun

    Process {
        id: read
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: out
            // -m prints one line: device,class,current,percent%,max
            onStreamFinished: {
                const p = parseInt(out.text.split(",")[3]);
                if (!isNaN(p)) root.percent = p;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: read.running = true
    }

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            if (root.percent < 0) return;
            const next = Math.max(1, Math.min(100, root.percent + (wheel.angleDelta.y > 0 ? 5 : -5)));
            root.percent = next;
            Quickshell.execDetached(["brightnessctl", "-q", "set", next + "%"]);
        }
    }
}
