pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

// Active MPRIS player: the playing one first, else the first paused one. Stopped players are ignored.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying)
        ?? players.find(p => p.playbackState !== MprisPlaybackState.Stopped) ?? null
    readonly property bool active: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player ? (player.trackTitle || player.identity) : ""
    readonly property string artist: player?.trackArtist ?? ""

    function togglePlaying() { if (active && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (active && player.canGoNext) player.next(); }
    function previous() { if (active && player.canGoPrevious) player.previous(); }
    function stepVolume(direction) { // 1 or -1
        if (active && player.canControl && player.volumeSupported)
            player.volume = Math.max(0, Math.min(1, player.volume + direction * Audio.stepSize));
    }
}
