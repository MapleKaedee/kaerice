
// Layout:
//   config/      design tokens (Theme)
//   services/    state + actions, no UI (singletons)
//   components/  UI: base/ primitives, bar/, dashboard/, editor/, lock/, notifications/, osd/, overlays/, settings/, wallpaper/
//   ipc/         IPC entry points for keybinds
import Quickshell
import qs.components.bar
import qs.components.dashboard
import qs.components.editor
import qs.components.lock
import qs.components.notifications
import qs.components.osd
import qs.components.overlays
import qs.components.settings
import qs.components.wallpaper
import qs.ipc
import qs.services

ShellRoot {
    // reading Idle creates the singleton, so the idle stages run from startup
    readonly property bool keepAwake: Idle.keepAwake
    // same for Battery: its warnings must not depend on the bar card
    readonly property int batteryPercent: Battery.percent
    // and LockKeys: it needs the lock state from before the first key press
    readonly property bool lockKeyOn: LockKeys.on
    // and the apps: the scan adds them one by one, so a launcher that starts it fills up row by row
    readonly property var apps: DesktopEntries.applications

    WallpaperLayer {}
    Bar {}
    NotificationPopups {}
    LevelOsd {}
    LockKeysOsd {}

    // only while open: these cost the most memory, or keep working on changes while they are closed
    LazyLoader { active: Ui.notifications; NotificationCenter {} }
    LazyLoader { active: Ui.dashboard; Dashboard {} }
    LazyLoader { active: Ui.controlCenter; ControlCenter {} }
    LazyLoader { active: Ui.launcher; Launcher {} }
    LazyLoader { active: Ui.emoji; EmojiPicker {} }
    LazyLoader { active: Switcher.open; WindowSwitcher {} }
    LazyLoader { active: Ui.wallpaperPicker; WallpaperPicker {} }

    Calendar {}
    WifiMenu {}
    ClipboardMenu {}
    TempNote {}
    Keybinds {}
    PowerMenu {}
    SettingsPanel {}
    ScreenshotEditor {}

    Ipc {}
    LockScreen {}
}
