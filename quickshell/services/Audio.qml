pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default output (Pipewire sink): volume 0..1 and mute. Default input (source): mic level and mute.
Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink?.audio
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(volume * 100)

    function setVolume(v) { if (ready) sink.audio.volume = Math.max(0, Math.min(1, v)); }
    function step(delta) { setVolume(volume + delta); }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property int micPercent: Math.round((source?.audio?.volume ?? 0) * 100)
    function toggleMicMute() { if (source?.audio) source.audio.muted = !source.audio.muted; }

    // binds the nodes so their audio properties are live
    PwObjectTracker { objects: [root.sink, root.source] }
}
