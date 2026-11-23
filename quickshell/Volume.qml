import Quickshell.Services.Pipewire
import QtQuick

// Default output volume. Scroll = +/-3%, click = mute toggle.
TextCard {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round((sink?.audio?.volume ?? 0) * 100)

    visible: !!sink
    text: muted ? "MUTE" : "VOL " + percent + "%"
    fill: muted ? "#1c1c1c" : "#f2f0eb"
    textColor: muted ? "#f2f0eb" : "#1c1c1c"

    // binds the sink so its audio properties are live
    PwObjectTracker { objects: [root.sink] }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        onWheel: wheel => {
            if (!root.sink?.audio) return;
            const step = wheel.angleDelta.y > 0 ? 0.03 : -0.03;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
