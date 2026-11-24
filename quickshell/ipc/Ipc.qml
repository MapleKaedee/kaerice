import Quickshell
import Quickshell.Io
import qs.services

// Every IPC entry point (Hyprland keybinds call these): qs -c kaerice ipc call <target> <function> [args]
// List them with: qs -c kaerice ipc show
Scope {
    IpcHandler {
        target: "launcher"
        function toggle(): void { Ui.launcher = !Ui.launcher; }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Ui.power = !Ui.power; }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { Ui.wifi = !Ui.wifi; }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { Ui.notifications = !Ui.notifications; }
        function toggleDnd(): void { Notifs.dnd = !Notifs.dnd; }
        function clear(): void { Notifs.clearAll(); }
    }

    // media keys: change the level and show the OSD
    IpcHandler {
        target: "osd"
        function volumeUp(): void { Audio.step(0.03); Osd.show("volume"); }
        function volumeDown(): void { Audio.step(-0.03); Osd.show("volume"); }
        function toggleMute(): void { Audio.toggleMute(); Osd.show("volume"); }
        function brightnessUp(): void { Brightness.step(5); Osd.show("brightness"); }
        function brightnessDown(): void { Brightness.step(-5); Osd.show("brightness"); }
    }

    // media keys: active MPRIS player (no playerctl needed)
    IpcHandler {
        target: "media"
        function playPause(): void { Media.togglePlaying(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
        function volumeUp(): void { Media.stepVolume(0.03); }
        function volumeDown(): void { Media.stepVolume(-0.03); }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { Ui.calendar = !Ui.calendar; }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock(); }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { Ui.clipboard = !Ui.clipboard; }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Wallpaper.apply(path); }
        function get(): string { return Wallpaper.source; }
        function pick(): void { Ui.wallpaperPicker = !Ui.wallpaperPicker; }
    }
}
