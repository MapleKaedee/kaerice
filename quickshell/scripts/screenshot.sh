#!/bin/sh
# Capture to a temporary file and open it in the kaerice editor, which decides:
# save to ~/Pictures/Screenshots (+ copy), copy only, or discard.
# Without a running shell, the capture is saved and copied directly.
# Usage: screenshot.sh region|screen|window
mode=${1:-region}
name="$(date +%Y-%m-%d_%H-%M-%S).png"
tmp="${XDG_RUNTIME_DIR:-/tmp}/kaerice-screenshot"
mkdir -p "$tmp"

case $mode in
    region) geom=$(slurp) || exit 0 ;; # Esc in slurp: no screenshot
    window) geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
    *) geom= ;;
esac

if [ -n "$geom" ]; then grim -g "$geom" "$tmp/$name"; else grim "$tmp/$name"; fi || exit 1

qs -c kaerice ipc call screenshot edit "$tmp/$name" && exit 0

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir" && mv "$tmp/$name" "$dir/$name" && wl-copy --type image/png < "$dir/$name"
