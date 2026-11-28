#!/bin/sh
# greeter-sync.sh <settings.json> <wallpaper>: copy the theme and the wallpaper to where the login screen reads them.
# The greeter runs as the user "greeter" and cannot read $HOME. install-greeter.sh creates the folder.
dir=/var/lib/kaerice-greeter
[ -w "$dir" ] || exit 0 # the greeter is not installed

# through a temporary file, so the greeter never reads half of one; 644 whatever the umask
install -d -m 755 "$dir/kaerice"
if [ -f "$1" ]; then
    install -m 644 "$1" "$dir/kaerice/settings.json.tmp" && mv "$dir/kaerice/settings.json.tmp" "$dir/kaerice/settings.json"
else
    rm -f "$dir/kaerice/settings.json" # no file means the defaults, there too
fi
if [ -n "$2" ]; then
    install -m 644 "$2" "$dir/wallpaper.tmp" && mv "$dir/wallpaper.tmp" "$dir/wallpaper"
fi
