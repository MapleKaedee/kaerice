import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Every IPC entry point (Hyprland keybinds call these): qs -c kaerice ipc call <target> <function> [args]
// List them with: qs -c kaerice ipc show
Scope {
    // Alt+Tab uses Hyprland global shortcuts (hl.dsp.global("quickshell:<name>")), not `qs ipc`:
    // they arrive in order and without spawning a process, so fast Tab presses are not lost.
    GlobalShortcut {
        name: "switcherNext"
        onPressed: Switcher.step(1)
    }
    GlobalShortcut {
        name: "switcherPrev"
        onPressed: Switcher.step(-1)
    }

    IpcHandler {
        target: "switcher"
        function next(): void { Switcher.step(1); }
        function prev(): void { Switcher.step(-1); }
        function commit(): void { Switcher.commit(); }
        function cancel(): void { Switcher.cancel(); }
        function overview(): void { Switcher.toggleOverview(); }
    }

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
        function volumeUp(): void { Audio.step(1); Osd.show("volume"); }
        function volumeDown(): void { Audio.step(-1); Osd.show("volume"); }
        function toggleMute(): void { Audio.toggleMute(); Osd.show("volume"); }
        function brightnessUp(): void { Brightness.step(5); Osd.show("brightness"); }
        function brightnessDown(): void { Brightness.step(-5); Osd.show("brightness"); }
        function capsLock(): void { LockKeys.released("capsLock"); }
        function numLock(): void { LockKeys.released("numLock"); }
    }

    // media keys: active MPRIS player (no playerctl needed)
    IpcHandler {
        target: "media"
        function playPause(): void { Media.togglePlaying(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
        function volumeUp(): void { Media.stepVolume(1); }
        function volumeDown(): void { Media.stepVolume(-1); }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle(): void { Ui.controlCenter = !Ui.controlCenter; }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { Ui.dashboard = !Ui.dashboard; }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { Ui.calendar = !Ui.calendar; }
    }

    IpcHandler {
        target: "idle"
        function toggleKeepAwake(): void { Idle.keepAwake = !Idle.keepAwake; }
        function keepAwake(): bool { return Idle.keepAwake; }
    }

    IpcHandler {
        target: "screenshot"
        function take(mode: string): void { Screenshot.take(mode); } // region | screen | window
        function edit(path: string): void { Screenshot.edit(path); }
        function save(): void { Screenshot.finishRequested(true); }
        function copy(): void { Screenshot.finishRequested(false); }
        function discard(): void { if (Screenshot.editing) Screenshot.discard(); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock(); }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { Ui.settings = !Ui.settings; }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void { Ui.keybinds = !Ui.keybinds; }
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { Ui.emoji = !Ui.emoji; }
    }

    IpcHandler {
        target: "note"
        function toggle(): void { Ui.note = !Ui.note; }
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
