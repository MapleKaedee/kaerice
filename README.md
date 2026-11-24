# kaerice

Hyprland rice with a hand-written Quickshell shell. Neo-brutal style: flat cards, thick borders, hard shadows.

## Install

```sh
./install.sh
```

Symlinks everything into `~/.config` (existing real files are moved to `*.pre-kaerice` first):

| Repo | Linked to |
| --- | --- |
| `hypr/` | `~/.config/hypr` |
| `quickshell/` | `~/.config/quickshell/kaerice` |
| `systemd/dms.service.d/skip-hyprland.conf` | `~/.config/systemd/user/dms.service.d/` (keeps DMS off on Hyprland) |

Needs: `hyprland`, `quickshell`, `ttf-jetbrains-mono-nerd`, `hyprpolkitagent`, `brightnessctl`, `cava`, `cliphist`, `accountsservice`, `zenity`,
`wl-clipboard`, `grim`, `slurp`, `jq`. Network uses iwd + systemd-networkd.

Restart the shell after big changes: `qs kill -c kaerice && qs -c kaerice`

## Keys

| Key | Action |
| --- | --- |
| `SUPER+/` | Keybind cheat sheet (searchable) |
| `SUPER+Space` | Launcher |
| `SUPER+D` | Dashboard: profile, clock, media, CPU/RAM/disk, calendar |
| `SUPER+,` | Settings (Sound & media, Power, Notifications, Users & accounts, About); also the gear in the control center |
| `SUPER+A` | Control center: sliders, per-app volume mixer, Wi-Fi, Bluetooth, audio, quick toggles (Silent, Awake, Dark for apps) |
| `SUPER+V` | Clipboard history |
| `SUPER+;` | Emoji picker (search, `Enter` copies; recent first) |
| `SUPER+SHIFT+N` | Temp note (saved automatically) |
| `SUPER+N` | Notification history |
| `SUPER+Y` | Wallpaper picker |
| `SUPER+X`, `SUPER+SHIFT+E` | Power menu: hold `Enter` or the mouse button on Suspend / Logout / Reboot / Shutdown (2 s longer, with a warning, while a package manager or download runs). Lock needs no hold |
| `SUPER+ALT+L` | Lock screen |
| `ALT+Tab` / `ALT+SHIFT+Tab` | Window switcher with live previews; release `ALT` to switch, `Esc` cancels |
| `SUPER+Tab` | Overview: every window by workspace; arrows + `Enter` or click to focus |
| Volume / mute / brightness keys | Change level and show the OSD |
| `Caps Lock` / `Num Lock` | Show ON / OFF in the OSD |
| Media keys (`CTRL`+volume = player volume) | Control the active MPRIS player |
| `Print` / `CTRL+Print` / `ALT+Print` | Screenshot region / screen / window, straight into the editor (arrow, marker, crop). `Enter` saves one file to `~/Pictures/Screenshots` + copies, `Ctrl+C` copies only, `Esc` discards |

Click the network card for the Wi-Fi menu, the bell card for notifications, the clock for the calendar, the distro logo for the control center. Scroll the volume and brightness cards.
A red card with the app name shows while the mic is recorded or a screen/camera is shared. Battery notifications come at 20 / 10 / 5 / 3 % and when the charger is connected or disconnected (warnings only). The media card sits between the bar rows; click it for the dashboard. While music plays, a cava spectrum rises behind the bar cards.
All shell actions are also IPC calls: `qs -c kaerice ipc show`.

## Lock and idle

The lock screen unlocks with your login password (PAM `login`). It also locks before every suspend.
Default idle stages, counted from the last input: dim at 2.5 min, lock at 5 min, screen off at 5.5 min,
suspend at 30 min (on battery only). Apps that inhibit idle, such as video players, pause every stage, and so does Awake in the control center.
Change the times in settings, Power.

If the lock ever refuses a correct password:
1. Switch to a TTY (`CTRL+ALT+F3`) and log in.
2. Three wrong passwords lock the account for 10 min. Clear that with `faillock --user $USER --reset`, then go back (`CTRL+ALT+F1` or `F2`) and try again.
3. Still stuck? Run `rm ~/.local/state/quickshell/by-shell/*/locked` first, so the shell starts unlocked, then `pkill -x Hyprland` (open windows are lost).

## Layout

```
hypr/                 Hyprland (Lua): hyprland.lua + conf/ modules
quickshell/
  shell.qml           root: places every surface
  config/Theme.qml    colors, fonts, card shape. Change the look here.
  config/cava.conf    cava settings for the bar visualizer
  config/emoji.tsv    emoji list (unicode.org emoji-test.txt, filtered to Noto Color Emoji)
  services/           state + actions, no UI (singletons): Audio, Brightness, Network, Wifi, Notifs, Clipboard, Wallpaper, Osd, Media, Cava, Screenshot, Emoji, Note, AppTheme, Privacy, Session, Battery, LockKeys, Settings, SystemInfo, Account, Lock, Switcher, SysStats, Idle, Ui
  components/
    base/             Card, TextCard, TextButton, IconButton, LevelSlider, DeviceList, Avatar, MonthCalendar, Overlay (full-screen layer with Esc/backdrop close)
    dashboard/        dashboard panel and its cards
    editor/           screenshot editor
    lock/             session lock surface
    bar/              top bar and its cards
    notifications/    popups, history panel
    osd/              volume/brightness and Caps/Num Lock popups
    overlays/         launcher, power menu, Wi-Fi, clipboard, emoji, note, keybinds, calendar, control center, window switcher + overview
    settings/         settings overlay and its pages
    wallpaper/        background layer, picker
  ipc/Ipc.qml         every IPC target used by keybinds
  scripts/            shell helpers run by keybinds (screenshot.sh)
settings/             settings.json: only values that differ from the defaults (services/SettingsSchema.js)
wallpapers/           images for the picker
tests/                logic tests: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
systemd/              DMS drop-in
```

Adding a feature: state and commands go in a `services/` singleton, UI in `components/`, colors from `Theme`,
open/close flags in `services/Ui.qml`, and the keybind entry point in `ipc/Ipc.qml`.
Imports use the shell root: `import qs.services`, `import qs.components.base`.
