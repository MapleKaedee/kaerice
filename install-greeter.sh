#!/bin/sh
# Install the kaerice login screen for greetd. Run again after editing the greeter: the copy is not live.
#   sudo ./install-greeter.sh           copy the files
#   sudo ./install-greeter.sh --enable  also point greetd at it; the old config goes to config.toml.pre-kaerice
set -eu

user=${SUDO_USER:-}
if [ "$(id -u)" != 0 ] || [ -z "$user" ]; then
	echo "run with sudo" >&2
	exit 1
fi

repo=$(cd "$(dirname "$0")" && pwd)
share=/usr/share/kaerice-greeter

mkdir -p "$share/quickshell"
rsync -a --delete --chown=root:root "$repo/quickshell/" "$share/quickshell/"
install -m 644 "$repo/greeter/mango.conf" "$repo/greeter/input.conf" "$share/"
install -m 755 "$repo/greeter/start.sh" "$share/"
# the user's shell writes the theme here (greeter-sync.sh), the greeter reads it
install -d -o "$user" -m 755 /var/lib/kaerice-greeter
install -d -o greeter -g greeter -m 700 /var/cache/kaerice-greeter
echo "installed: $share"

[ "${1:-}" = --enable ] || exit 0

cfg=/etc/greetd/config.toml
if grep -qF "$share/mango.conf" "$cfg"; then
	echo "already enabled"
	exit 0
fi
if [ -e "$cfg.pre-kaerice" ]; then
	echo "abort: $cfg.pre-kaerice already exists, move it away first" >&2
	exit 1
fi
mv "$cfg" "$cfg.pre-kaerice"
cat >"$cfg" <<EOF
[terminal]
vt = 1

[default_session]
command = "mango -c $share/mango.conf"
user = "greeter"
EOF
echo "enabled: reboot to see it. Never restart greetd from a graphical session: that ends the session."
echo "back:    sudo mv $cfg.pre-kaerice $cfg"
