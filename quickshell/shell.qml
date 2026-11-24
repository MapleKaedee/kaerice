//@ pragma UseQApplication
// UseQApplication: required for tray right-click menus (platform menus); needs a qs restart

// Layout:
//   config/      design tokens (Theme)
//   services/    state + actions, no UI (singletons)
//   components/  UI: base/ primitives, bar/, dashboard/, editor/, lock/, notifications/, osd/, overlays/, wallpaper/
//   ipc/         IPC entry points for keybinds
import Quickshell
import qs.components.bar
import qs.components.dashboard
import qs.components.editor
import qs.components.lock
import qs.components.notifications
import qs.components.osd
import qs.components.overlays
import qs.components.wallpaper
import qs.ipc
import qs.services

ShellRoot {
    // reading Idle creates the singleton, so the idle stages run from startup
    readonly property bool keepAwake: Idle.keepAwake

    WallpaperLayer {}
    Bar {}
    NotificationPopups {}
    LevelOsd {}

    NotificationCenter {}
    Dashboard {}
    ControlCenter {}
    Calendar {}
    WifiMenu {}
    Launcher {}
    ClipboardMenu {}
    EmojiPicker {}
    TempNote {}
    PowerMenu {}
    WallpaperPicker {}
    WindowSwitcher {}
    ScreenshotEditor {}

    Ipc {}
    LockScreen {}
}
