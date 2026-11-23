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
link systemd/dms.service.d/skip-hyprland.conf "$cfg/systemd/user/dms.service.d/skip-hyprland.conf"

systemctl --user daemon-reload
