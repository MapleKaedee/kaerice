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
    readonly property bool playing: active && player.isPlaying
    readonly property string title: active ? (player.trackTitle || player.identity) : ""
    readonly property string artist: active ? player.trackArtist : ""

    function togglePlaying() { if (active && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (active && player.canGoNext) player.next(); }
    function previous() { if (active && player.canGoPrevious) player.previous(); }
    function stepVolume(delta) {
        if (active && player.canControl && player.volumeSupported)
            player.volume = Math.max(0, Math.min(1, player.volume + delta));
    }
}
