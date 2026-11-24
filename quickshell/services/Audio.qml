pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default output (Pipewire sink): volume 0..1 and mute. Default input (source): mic level and mute.
// Per-app playback streams (volume mixer), grouped by app name.
Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink?.audio
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(volume * 100)

    function setVolume(v) { if (ready) sink.audio.volume = Math.max(0, Math.min(1, v)); }
    readonly property real stepSize: Settings.get("sound.volumeStep") / 100
    function step(direction) { setVolume(volume + direction * stepSize); } // 1 or -1
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property int micPercent: Math.round(micVolume * 100)
    function setMicVolume(v) { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleMicMute() { if (source?.audio) source.audio.muted = !source.audio.muted; }

    // devices to choose from; WirePlumber remembers the choice
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)
    function useSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function useSource(node) { Pipewire.preferredDefaultAudioSource = node; }
    function deviceName(node) { return node.description || node.nickname || node.name; }
    function shortName(node) { return node?.nickname || node?.description || ""; } // no "Analog Stereo"

    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream && n.audio)
    // [{ name, id (for the icon lookup), nodes }]; one row per app even when it has several streams
    readonly property var apps: {
        const byName = {};
        for (const n of streams) {
            const name = n.properties["application.name"] || n.description || n.name;
            if (!byName[name]) byName[name] = { name: name, id: n.properties["application.process.binary"] || name, nodes: [] };
            byName[name].nodes.push(n);
        }
        return Object.values(byName);
    }
    function setAppVolume(app, v) { for (const n of app?.nodes ?? []) if (n.audio) n.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleAppMute(app) {
        if (!app) return;
        const mute = !app.nodes[0]?.audio?.muted;
        for (const n of app.nodes) if (n.audio) n.audio.muted = mute;
    }

    // binds the nodes so their audio properties are live
    PwObjectTracker { objects: [root.sink, root.source].concat(root.streams) }
}
