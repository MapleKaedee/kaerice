//@ pragma UseQApplication
// UseQApplication: required for tray right-click menus (platform menus); needs a qs restart

// Layout:
//   config/      design tokens (Theme)
//   services/    state + actions, no UI (singletons)
//   components/  UI: base/ primitives, bar/, dashboard/, lock/, notifications/, osd/, overlays/, wallpaper/
//   ipc/         IPC entry points for keybinds
import Quickshell
import qs.components.bar
import qs.components.dashboard
import qs.components.lock
import qs.components.notifications
import qs.components.osd
import qs.components.overlays
import qs.components.wallpaper
import qs.ipc
import qs.services

ShellRoot {
    WallpaperLayer {}
    Bar {}
    NotificationPopups {}
    LevelOsd {}

    NotificationCenter {}
    Dashboard {}
    Calendar {}
    WifiMenu {}
    Launcher {}
    ClipboardMenu {}
    PowerMenu {}
    WallpaperPicker {}
    WindowSwitcher {}

    Ipc {}
    Idle {}
    LockScreen {}
}
