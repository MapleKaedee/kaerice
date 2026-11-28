# kaerice

Hyprland and Mango rice with a hand-written Quickshell shell. Neo-brutal style: flat cards, thick borders, hard shadows.

## Install

```sh
./install.sh
```

Symlinks everything into `~/.config` (existing real files are moved to `*.pre-kaerice` first):

| Repo | Linked to |
| --- | --- |
| `hypr/` | `~/.config/hypr` |
| `mango/` | `~/.config/mango` |
| `quickshell/` | `~/.config/quickshell/kaerice` |
| `systemd/kaericed.service` | `~/.config/systemd/user/kaericed.service` |

Needs: `hyprland` or `mangowm`, `quickshell`, `ttf-jetbrains-mono-nerd`, `cava`, `cliphist`, `accountsservice`, `zenity`, `curl`,
`wl-clipboard`, `grim`, `slurp`, `jq`, `libarchive`. Network uses iwd + systemd-networkd. Optional: `xorg-xsetroot` (see Cursor).

`nix` builds the daemon `kaericed` (`core/`) and is needed for the network status, the Wi-Fi menu, brightness, system usage and
the cursor: without it those show `N/A`, `--` or `Unavailable`, the brightness keys do nothing, and the rest works. Run `./install.sh`
again after a `git pull`: QML changes are live at once, the daemon only after that.

Working on the daemon in `core/`: see [env.md](env.md).

Restart the shell after big changes: `pkill -9 -x "qs|quickshell"; env MALLOC_CONF=narenas:1 qs -c kaerice` (`qs kill` shortly after a hot reload crashes Quickshell 0.3.2)

## Keys

| Key | Action |
| --- | --- |
| `SUPER+/` | Keybind cheat sheet (searchable) |
| `SUPER+Space` | Launcher |
| `SUPER+D` | Dashboard: profile, clock, media, CPU/RAM/disk, calendar |
| `SUPER+,` | Settings (Theme, Bar, Sound & media, Power, Notifications, Users & accounts, About); also the gear in the control center |
| `SUPER+A` | Control center: sliders, per-app volume mixer, Wi-Fi, Bluetooth, output and input (click the tile to pick a device, its icon to mute), quick toggles (Silent, Awake, Dark for apps) |
| `SUPER+V` | Clipboard history |
| `SUPER+;` | Emoji picker (search, `Enter` copies; recent first) |
| `SUPER+SHIFT+N` | Temp note (saved automatically) |
| `SUPER+N` | Notification history |
| `SUPER+Y` | Wallpaper picker, two tabs (`Tab` switches): images from `wallpapers/` and `~/Pictures/Wallpapers` (`Del` twice moves one to the Trash), and Wallhaven (search and filters; `Enter` or a click downloads and uses, `D` only downloads) |
| `SUPER+X`, `SUPER+SHIFT+E` | Power menu: hold `Enter` or the mouse button on Suspend / Logout / Reboot / Shutdown (2 s longer, with a warning, while a package manager or download runs). Lock needs no hold |
| `SUPER+ALT+L` | Lock screen |
| `ALT+Tab` / `ALT+SHIFT+Tab` | Window switcher with live previews; release `ALT` to switch, `Esc` cancels |
| `SUPER+Tab` | Overview: every window by workspace; arrows + `Enter` or click to focus |
| Volume / mute / brightness keys | Change level and show the OSD |
| `Caps Lock` / `Num Lock` | Show ON / OFF in the OSD |
| Media keys (`CTRL`+volume = player volume) | Control the active MPRIS player |
| `Print` / `CTRL+Print` / `ALT+Print` | Screenshot region / screen / window, straight into the editor (arrow, marker, crop). `Enter` saves one file to `~/Pictures/Screenshots` + copies, `Ctrl+C` copies only, `Esc` discards |

On Mango the keys are the same (`mango/conf/binds*.conf`), except: no `SUPER+W` (group), `SUPER+Home` / `SUPER+End`
(first / last column) and `SUPER+.` (move to next column); the switcher and overview show app icons instead of live previews
(Quickshell 0.3.2 captures windows only on Hyprland); an Alt+Tab released within about 0.1 s leaves the switcher open: tap
`ALT` or press `Enter`.

Click the network card for the Wi-Fi menu, the bell card for notifications, the clock for the calendar, the distro logo for the control center. Scroll the volume and brightness cards.
A red card with the app name shows while the mic is recorded or a screen/camera is shared. Battery notifications come at 20 / 10 / 5 / 3 % and when the charger is connected or disconnected (warnings only). The media card sits between the bar rows; click it for the dashboard. While music plays, a cava spectrum rises behind the bar cards.
All shell actions are also IPC calls: `qs -c kaerice ipc show`.

## Lock and idle

The lock screen unlocks with your login password (PAM `login`). It also locks before every suspend, with or without `kaericed`.
Default idle stages, counted from the last input: dim at 2.5 min, lock at 5 min, screen off at 5.5 min,
suspend at 30 min (on battery only). Apps that inhibit idle, such as video players, pause every stage, and so does Awake in the control center.
Change the times in settings, Power.

If the lock ever refuses a correct password:
1. Switch to a TTY (`CTRL+ALT+F3`) and log in.
2. Three wrong passwords lock the account for 10 min. Clear that with `faillock --user $USER --reset`, then go back (`CTRL+ALT+F1` or `F2`) and try again.
3. Still stuck? Run `rm ~/.local/state/quickshell/by-shell/*/locked` first, so the shell starts unlocked, then `pkill -x Hyprland` or `pkill -x mango` (open windows are lost).

## Login screen

A greetd greeter in the same style: wallpaper, clock, your avatar and name, the password, and the session to start
(Up/Down or a click changes it; the last one is kept). It runs as the user `greeter` in a Mango of its own, from a copy of `quickshell/`.

1. Check that a TTY login works (`CTRL+ALT+F2`): it is the way back if the greeter fails.
2. `sudo ./install-greeter.sh` copies it to `/usr/share/kaerice-greeter`. Run it again after editing the greeter, then log out: the copy is not live.
3. `sudo ./install-greeter.sh --enable` points `/etc/greetd/config.toml` at it; the old file becomes `config.toml.pre-kaerice`.
4. Reboot. Never `systemctl restart greetd` from a graphical session: that ends the session.

The shell copies the theme and the wallpaper to `/var/lib/kaerice-greeter` at start and at every change (`scripts/greeter-sync.sh`).
To go back, from a TTY: `sudo mv /etc/greetd/config.toml.pre-kaerice /etc/greetd/config.toml`, then reboot.

## Cursor

Settings, Theme picks a cursor theme from `~/.local/share/icons`, `~/.icons` and `/usr/share/icons`, and a size from 16 to 96 px.
`kaericed` copies the theme in that size to `~/.local/share/icons/kaerice-cursor-<theme>-<size>` (the theme itself stays as it is) and makes
the copy the theme `default`, for Wayland, X11, XWayland and Flatpak apps. The first time, a `default` that is already in `~/.icons` or
`~/.local/share/icons` moves to `default.pre-kaerice`, and the cursor theme named in the GTK `settings.ini` files, `~/.gtkrc-2.0` or `~/.Xresources`
becomes `default`. To undo it, delete both `default` links and put `default.pre-kaerice` back.

Install next to it, or `quickshell/scripts/install-cursor.sh FILE`, adds a downloaded theme to `~/.local/share/icons`: Linux themes are
copied, Windows cursors (`.cur` and `.ani`, with or without an `install.inf`) converted. It takes a folder, a `.zip`, `.7z`, `.rar`, `.cab`,
`.tar.*`, `.deskthemepack`, or an `.exe` that holds an archive. Nothing in it is run, and a theme that is already there is never replaced. To
remove a theme, delete its folder. Hyprcursor and CursorFX themes, `.cape`, loose images and installers that only unpack by running cannot be used.

- Apps that are open and load the cursor themselves change when they are opened again. With `xorg-xsetroot`, X11 windows without a cursor
  of their own change at once, without it at the next login.
- Not reached: games with a cursor of their own, apps run as root and the login screen.
- On a screen scaled above 1 the cursor is smaller than the number.

## Layout

```
hypr/                 Hyprland (Lua): hyprland.lua + conf/ modules
mango/                Mango: config.conf + conf/ modules (check with mango -c ~/.config/mango/config.conf -p)
quickshell/
  shell.qml           root: places every surface
  greeter.qml         the login screen, run by greetd from the copy of install-greeter.sh (README: Login screen)
  config/Theme.qml    colors, fonts, card shape. Mode, accent and shape are chosen in settings, Theme.
  config/cava.conf    cava settings for the bar visualizer
  config/emoji.tsv    emoji list (unicode.org emoji-test.txt, filtered to Noto Color Emoji)
  services/           state + actions, no UI (singletons): Audio, Backend (kaericed connection), Brightness, Network, Wifi, Notifs, Clipboard, Wallpaper, Wallhaven, Osd, Compositor (Hyprland or Mango), Media, Cava, Screenshot, Emoji, Note, AppTheme, Cursor, Privacy, Session, Battery, LockKeys, Settings, BarLayout, SystemInfo, Account, Lock, Switcher, SysStats, Idle, Ui, Greeter (login screen only), GreeterSync
  components/
    base/             Card, TextButton, IconButton, Choice, LevelSlider, DeviceList, Avatar, MonthCalendar, Overlay (full-screen layer with Esc/backdrop close)
    dashboard/        dashboard panel and its cards
    editor/           screenshot editor
    lock/             session lock surface
    greeter/          login screen surface
    bar/              top bar and its cards
    notifications/    popups, history panel
    osd/              volume/brightness and Caps/Num Lock popups
    overlays/         launcher, power menu, Wi-Fi, clipboard, emoji, note, keybinds, calendar, control center, window switcher + overview
    settings/         settings overlay and its pages
    wallpaper/        background layer, picker (local images, Wallhaven)
  ipc/Ipc.qml         every IPC target used by keybinds
  scripts/            shell helpers (screenshot.sh, install-cursor.sh, greeter-sync.sh)
greeter/              the login screen's Mango config and start script
settings/             your settings.json (not in git): only values that differ from the defaults (services/SettingsSchema.js)
wallpapers/           images for the picker
tests/                logic tests: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
core/                 kaericed, the daemon (Rust): sends state to the shell and takes its calls over a Unix socket, one JSON line each
systemd/              kaericed unit
```

Adding a feature: state and commands go in a `services/` singleton, UI in `components/`, colors and sizes from `Theme`,
open/close flags in `services/Ui.qml`, and the keybind entry point in `ipc/Ipc.qml`.
Imports use the shell root: `import qs.services`, `import qs.components.base`.
