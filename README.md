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

Needs: `hyprland`, `quickshell`, `ttf-jetbrains-mono-nerd`, `hyprpolkitagent`, `brightnessctl`, `cliphist`,
`wl-clipboard`, `grim`, `slurp`, `jq`. Network uses iwd + systemd-networkd.

Restart the shell after big changes: `qs kill -c kaerice && qs -c kaerice`

## Keys

| Key | Action |
| --- | --- |
| `SUPER+Space` | Launcher |
| `SUPER+D` | Dashboard: profile, clock, media, CPU/RAM/disk, calendar |
| `SUPER+V` | Clipboard history |
| `SUPER+N` | Notification history |
| `SUPER+Y` | Wallpaper picker |
| `SUPER+X`, `SUPER+SHIFT+E` | Power menu |
| `SUPER+ALT+L` | Lock screen |
| `ALT+Tab` / `ALT+SHIFT+Tab` | Window switcher with live previews; release `ALT` to switch, `Esc` cancels |
| `SUPER+Tab` | Overview: every window by workspace; arrows + `Enter` or click to focus |
| Volume / mute / brightness keys | Change level and show the OSD |
| Media keys (`CTRL`+volume = player volume) | Control the active MPRIS player |
| `Print` / `CTRL+Print` / `ALT+Print` | Screenshot region / screen / window to clipboard |

Click the network card for the Wi-Fi menu, the bell card for notifications, the clock for the calendar. Scroll the volume and brightness cards.
The media card (bar center) shows while a player is playing or paused.
All shell actions are also IPC calls: `qs -c kaerice ipc show`.

## Lock and idle

The lock screen unlocks with your login password (PAM `login`). It also locks before every suspend.
Idle stages, counted from the last input: dim at 2.5 min, lock at 5 min, screen off at 5.5 min,
suspend at 30 min (on battery only). Apps that inhibit idle, such as video players, pause every stage.
Change the times in `quickshell/services/Idle.qml`.

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
  services/           state + actions, no UI (singletons): Audio, Brightness, Network, Wifi, Notifs, Clipboard, Wallpaper, Osd, Media, Lock, Switcher, SysStats, Ui; Idle (stages)
  components/
    base/             Card, TextCard, IconButton, MonthCalendar, Overlay (full-screen layer with Esc/backdrop close)
    dashboard/        dashboard panel and its cards
    lock/             session lock surface
    bar/              top bar and its cards
    notifications/    popups, history panel
    osd/              volume/brightness level popup
    overlays/         launcher, power menu, Wi-Fi, clipboard, calendar, window switcher + overview
    wallpaper/        background layer, picker
  ipc/Ipc.qml         every IPC target used by keybinds
wallpapers/           images for the picker
systemd/              DMS drop-in
```

Adding a feature: state and commands go in a `services/` singleton, UI in `components/`, colors from `Theme`,
open/close flags in `services/Ui.qml`, and the keybind entry point in `ipc/Ipc.qml`.
Imports use the shell root: `import qs.services`, `import qs.components.base`.
