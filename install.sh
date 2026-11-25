#!/bin/sh
# Link kaerice configs into ~/.config. Safe to re-run.
# A real file/dir already at a target is moved to <target>.pre-kaerice first (never deleted).
set -eu

repo=$(cd "$(dirname "$0")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}

link() { # link <path-in-repo> <target>
    src=$repo/$1
    dst=$2
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        if [ -e "$dst.pre-kaerice" ]; then
            echo "abort: $dst.pre-kaerice already exists, move it away first" >&2
            exit 1
        fi
        mv "$dst" "$dst.pre-kaerice"
        echo "backup: $dst -> $dst.pre-kaerice"
    fi
    ln -sfnT "$src" "$dst"
    echo "link:   $dst -> $src"
}

link hypr "$cfg/hypr"
link quickshell "$cfg/quickshell/kaerice"
mkdir -p "$repo/settings" # not in git
link settings "$cfg/kaerice" # the directory: an atomic write could replace a linked file
link systemd/dms.service.d/skip-hyprland.conf "$cfg/systemd/user/dms.service.d/skip-hyprland.conf"
link systemd/kaericed.service "$cfg/systemd/user/kaericed.service"

systemctl --user daemon-reload

# the out-link keeps the build from Nix garbage collection
core=${XDG_STATE_HOME:-$HOME/.local/state}/kaerice/core
if ! command -v nix > /dev/null; then
    echo "nix not found: kaericed was not built, network status stays N/A" >&2
elif mkdir -p "$(dirname "$core")" && nix --extra-experimental-features 'nix-command flakes' build "$repo#kaericed" --out-link "$core"; then
    systemctl --user enable kaericed.service
    if systemctl --user is-active --quiet hyprland-session.target; then systemctl --user restart kaericed.service; fi
else
    echo "build failed: kaericed was not changed" >&2
fi
