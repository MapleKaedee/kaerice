//@ pragma UseQApplication
// UseQApplication: required for tray right-click menus (platform menus); needs a qs restart

// Layout:
//   config/      design tokens (Theme)
//   services/    state + actions, no UI (singletons)
//   components/  UI: base/ primitives, bar/, notifications/, overlays/, wallpaper/
//   ipc/         IPC entry points for keybinds
import Quickshell
import qs.components.bar
import qs.components.notifications
import qs.components.overlays
import qs.components.wallpaper
import qs.ipc

ShellRoot {
    WallpaperLayer {}
    Bar {}
    NotificationPopups {}

    NotificationCenter {}
    WifiMenu {}
    Launcher {}
    ClipboardMenu {}
    PowerMenu {}
    WallpaperPicker {}

    Ipc {}
}
