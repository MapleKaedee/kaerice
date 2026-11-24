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
