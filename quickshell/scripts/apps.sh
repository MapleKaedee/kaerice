#!/bin/sh
# Autostart entries and default apps for the Applications settings page.
#   autostart               file<TAB>name<TAB>command, one line per entry
#   autostart-add COMMAND   prints the new file's name
#   autostart-remove FILE
#   defaults TYPE...        type<TAB>default<TAB>app;app;... (apps that declare the type), one line per type
#   default APP TYPE...     makes APP the default for the types it declares
set -eu
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
dir=$cfg/autostart

value() { sed -n "s/^$1=//p" "$2" | head -n 1; }

app_dirs() {
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    printf '%s\n' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' '\n' | sed 's|$|/applications|'
}

# MimeType=a/b;c/d; with or without the last ";"
pattern() { printf '^MimeType=(.*;)?%s(;|$)' "$(printf %s "$1" | sed 's/[.+]/\\&/g')"; }
declares() { grep -qE "$(pattern "$2")" "$1"; }

case ${1:-} in
autostart)
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue
        [ "$(value Hidden "$f")" = true ] && continue # an entry switched off
        printf '%s\t%s\t%s\n' "${f##*/}" "$(value Name "$f")" "$(value Exec "$f" | sed 's/%%/%/g; s/\\\\/\\/g')"
    done
    ;;
autostart-add)
    cmd=${2:-}
    case $cmd in *[!\ ]*) ;; *) echo "Type a command" >&2; exit 2 ;; esac
    word=$(printf %s "$cmd" | awk '{ print $1 }')
    slug=$(printf %s "${word##*/}" | tr -c 'A-Za-z0-9_-' '-')
    mkdir -p "$dir"
    f=$dir/kaerice-$slug.desktop
    n=2
    while [ -e "$f" ]; do f=$dir/kaerice-$slug-$n.desktop; n=$((n + 1)); done
    # Exec is unescaped twice: "\\" by the file format, "%%" as a field code
    exec_line=$(printf %s "$cmd" | sed 's/\\/\\\\/g; s/%/%%/g')
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n' "$slug" "$exec_line" > "$f"
    echo "${f##*/}"
    # the generator runs only when the user manager starts, which a quick re-login may not do
    systemctl --user daemon-reload
    ;;
autostart-remove)
    case ${2:-} in '' | */* | .*) echo "Not an autostart entry" >&2; exit 2 ;; esac
    rm -- "$dir/$2"
    systemctl --user daemon-reload
    ;;
defaults)
    shift
    for t in "$@"; do
        apps=$(app_dirs | while read -r d; do
            grep -lE "$(pattern "$t")" "$d"/*.desktop 2> /dev/null || true
        done | sed 's|.*/||' | sort -u | paste -sd ';')
        printf '%s\t%s\t%s\n' "$t" "$(xdg-mime query default "$t")" "$apps"
    done
    ;;
default)
    app=${2:-}
    shift 2
    file=$(app_dirs | while read -r d; do [ -f "$d/$app" ] && printf '%s\n' "$d/$app"; done | head -n 1)
    [ -n "$file" ] || { echo "$app not found" >&2; exit 2; }
    for t in "$@"; do
        if declares "$file" "$t"; then xdg-mime default "$app" "$t"; fi
    done
    ;;
*)
    echo "usage: apps.sh autostart | autostart-add COMMAND | autostart-remove FILE | defaults TYPE... | default APP TYPE..." >&2
    exit 2
    ;;
esac
