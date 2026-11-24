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

Needs: `hyprland`, `quickshell`, `ttf-jetbrains-mono-nerd`, `hyprpolkitagent`, `brightnessctl`, `playerctl`,
`cliphist`, `wl-clipboard`, `grim`, `slurp`, `jq`. Network uses iwd + systemd-networkd.

Restart the shell after big changes: `qs kill -c kaerice && qs -c kaerice`

## Keys

| Key | Action |
| --- | --- |
| `SUPER+Space` | Launcher |
| `SUPER+V` | Clipboard history |
| `SUPER+N` | Notification history |
| `SUPER+Y` | Wallpaper picker |
| `SUPER+X`, `SUPER+SHIFT+E` | Power menu |
| Volume / mute / brightness keys | Change level and show the OSD |
| `Print` / `CTRL+Print` / `ALT+Print` | Screenshot region / screen / window to clipboard |

Click the network card for the Wi-Fi menu, the bell card for notifications. Scroll the volume and brightness cards.
All shell actions are also IPC calls: `qs -c kaerice ipc show`.

## Layout

```
hypr/                 Hyprland (Lua): hyprland.lua + conf/ modules
quickshell/
  shell.qml           root: places every surface
  config/Theme.qml    colors, fonts, card shape. Change the look here.
  services/           state + actions, no UI (singletons): Audio, Brightness, Network, Wifi, Notifs, Clipboard, Wallpaper, Osd, Ui
  components/
    base/             Card, TextCard, Overlay (full-screen layer with Esc/backdrop close)
    bar/              top bar and its cards
    notifications/    popups, history panel
    osd/              volume/brightness level popup
    overlays/         launcher, power menu, Wi-Fi, clipboard
    wallpaper/        background layer, picker
  ipc/Ipc.qml         every IPC target used by keybinds
wallpapers/           images for the picker
systemd/              DMS drop-in
```

Adding a feature: state and commands go in a `services/` singleton, UI in `components/`, colors from `Theme`,
open/close flags in `services/Ui.qml`, and the keybind entry point in `ipc/Ipc.qml`.
Imports use the shell root: `import qs.services`, `import qs.components.base`.
