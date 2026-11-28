# kaerice

Mango and Hyprland rice. Neo-brutal style: flat cards, thick borders, hard shadows.

## Install

```sh
./install.sh
```

Links `hypr/`, `mango/`, `quickshell/` (as `quickshell/kaerice`), `settings/` (as `kaerice`), the `kaericed` unit and the
XDG autostart drop-in of both session targets into `~/.config`; existing files move to `*.pre-kaerice`. QML changes are live at
once; run it again after a `git pull` for the daemon.

Needs: `mangowm` or `hyprland`, `quickshell`, `ttf-jetbrains-mono-nerd`, `cava`, `cliphist`, `accountsservice`, `zenity`, `curl`,
`wl-clipboard`, `grim`, `slurp`, `jq`, `libarchive`, `xdg-utils`, iwd + systemd-networkd. Optional: `xorg-xsetroot`.

`nix` builds the daemon `kaericed` (`core/`, see [env.md](env.md)). Without it, network, Wi-Fi, brightness, system usage and
the cursor show `N/A`, `--` or `Unavailable`; the rest works.

Restart the shell: `pkill -9 -x "qs|quickshell"; env MALLOC_CONF=narenas:1 qs -c kaerice` (not `qs kill`: it crashes after a hot reload).

## Keys

| Key | Action |
| --- | --- |
| `SUPER+/` | Keybind cheat sheet |
| `SUPER+Space` | Launcher |
| `SUPER+D` | Dashboard |
| `SUPER+,` | Settings |
| `SUPER+A` | Control center: sliders, volume mixer, Wi-Fi, Bluetooth, devices, quick toggles |
| `SUPER+V` | Clipboard history |
| `SUPER+;` | Emoji picker |
| `SUPER+SHIFT+N` | Temp note |
| `SUPER+N` | Notification history |
| `SUPER+Y` | Wallpaper picker: local images and Wallhaven (`Tab` switches) |
| `SUPER+X`, `SUPER+SHIFT+E` | Power menu: hold `Enter` or the mouse button to confirm |
| `SUPER+ALT+L` | Lock screen |
| `ALT+Tab` / `ALT+SHIFT+Tab` | Window switcher; release `ALT` to switch |
| `SUPER+Tab` | Overview of every window |
| `Print` / `CTRL+Print` / `ALT+Print` | Screenshot region / screen / window into the editor |
| Volume, brightness, media, Caps/Num Lock | OSD and player control (`CTRL`+volume = player volume) |

Hyprland only: `SUPER+W`, `SUPER+Home` / `SUPER+End`, `SUPER+.` and live previews (Mango shows app icons). On Mango a very quick
`ALT+Tab` can leave the switcher open: tap `ALT` or press `Enter`.

Bar: click network (Wi-Fi), bell (notifications), clock (calendar), distro logo (control center); scroll volume and brightness.
Every action is also an IPC call: `qs -c kaerice ipc show`.

## Lock and idle

Unlocks with your login password. Idle: dim at 2.5 min, lock at 5 min, screen off at 5.5 min, suspend at 30 min (battery only).
Change it in Settings, Power.

If the lock refuses a correct password:
1. Switch to a TTY (`CTRL+ALT+F3`) and log in.
2. Run `faillock --user $USER --reset` (3 wrong passwords lock the account for 10 min), go back (`CTRL+ALT+F1` or `F2`), try again.
3. Still stuck: `rm ~/.local/state/quickshell/by-shell/*/locked`, then `pkill -x mango` or `pkill -x Hyprland` (open windows are lost).

## Login screen

A greetd greeter in the same style, run as the user `greeter` in a Mango of its own, from a copy of `quickshell/`.

1. Check that a TTY login works (`CTRL+ALT+F2`): it is the way back if the greeter fails.
2. `sudo ./install-greeter.sh` copies it to `/usr/share/kaerice-greeter`. Run it again after editing the greeter.
3. `sudo ./install-greeter.sh --enable` points `/etc/greetd/config.toml` at it (the old file becomes `config.toml.pre-kaerice`).
4. Reboot. Never `systemctl restart greetd` from a graphical session: that ends the session.

To go back, from a TTY: `sudo mv /etc/greetd/config.toml.pre-kaerice /etc/greetd/config.toml`, then reboot.

## Cursor

Settings, Theme picks a cursor theme and size (16 to 96 px). `kaericed` makes a copy in that size the theme `default` for Wayland,
X11, XWayland and Flatpak apps. An existing `default` moves to `default.pre-kaerice`; to undo, delete the `default` links in `~/.icons`
and `~/.local/share/icons` and put it back.

Install (or `quickshell/scripts/install-cursor.sh FILE`) adds a downloaded Linux or Windows (`.cur`, `.ani`) theme from a folder or an
archive. Nothing in it is run. Open apps change when opened again; games, root apps and the login screen keep their own cursor.

## Layout

```
hypr/          Hyprland config (Lua)
mango/         Mango config (check: mango -c ~/.config/mango/config.conf -p)
quickshell/
  shell.qml    root: places every surface
  greeter.qml  the login screen (see Login screen)
  config/      Theme.qml (colors, fonts, card shape), cava.conf, emoji.tsv
  services/    state + actions, no UI (singletons); Compositor.qml holds what differs per compositor
  components/  UI: base/ widgets, bar/, dashboard/, overlays/, settings/, lock/, greeter/, ...
  ipc/Ipc.qml  every IPC target used by keybinds
  scripts/     shell helpers
greeter/       the login screen's Mango config and start script
settings/      your settings.json (not in git): only values that differ from the defaults
wallpapers/    images for the picker
tests/         logic tests: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
core/          kaericed (Rust): sends state to the shell over a Unix socket, one JSON line each
systemd/       kaericed unit, XDG autostart drop-in (Settings, Applications)
```

Adding a feature: state and commands in a `services/` singleton, UI in `components/`, colors and sizes from `Theme`,
open/close flags in `services/Ui.qml`, the keybind entry point in `ipc/Ipc.qml`. Imports use the shell root: `import qs.services`.
