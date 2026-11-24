#!/usr/bin/env bash
# Disable the touchpad while an external mouse is connected (niri's disabled-on-external-mouse).
# Hyprland has no native option, so watch udev input events and config reloads.

TP=$(hyprctl devices -j | jq -r '.mice[].name | select(test("touchpad"))' | head -1)
[ -n "$TP" ] || exit 0
TP_PREFIX=${TP%-touchpad} # the touchpad's own "-mouse" node is internal, not external

apply() {
	local json state
	json=$(hyprctl devices -j) || exit 0 # Hyprland gone: stop watching
	# the SayoDevice keypad and the Wacom tablet have mouse nodes but are not mice
	if jq -e --arg p "$TP_PREFIX" \
		'[.mice[].name | select((startswith($p) or test("virtual|sayodevice|wacom")) | not)] | length > 0' \
		<<<"$json" >/dev/null; then
		state=false
	else
		state=true
	fi
	hyprctl repl "hl.device({ name = \"$TP\", enabled = $state })" >/dev/null
}

apply
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
{
	udevadm monitor --udev --subsystem-match=input &
	socat -u "UNIX-CONNECT:$SOCK" - | grep --line-buffered '^configreloaded'
} | while read -r _; do
	while read -r -t 0.5 _; do :; done # debounce: one plug fires many udev events
	apply
done
