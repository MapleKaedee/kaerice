#!/bin/sh
# Install the cursor themes in a folder, an archive or a .cur/.ani file: Linux themes are copied, Windows cursors
# converted (kaericed install-cursor). Nothing in it is run, an .exe is only opened as an archive.
# Prints the names of the new themes; why others are missing goes to stderr.
set -u

fail() {
	echo "$1" >&2
	exit 1
}

# FILE FOLDER ENTRIES BYTES: 2 if it holds more than that
unpack() {
	timeout 60 bsdtar -tv --numeric-owner -f "$1" 2> /dev/null |
		awk -v n="$3" -v b="$4" '{ n--; b -= $5 } END { exit NR == 0 ? 1 : n < 0 || b < 0 ? 2 : 0 }' || return
	mkdir "$2" 2> /dev/null || return 1
	timeout 60 bsdtar -xf "$1" -C "$2" 2> /dev/null
	chmod -R u+rwX "$2"
}

# from find, below: IN FILE, with what is left of the 5000 entries and 1 GB for the whole download
if [ "${1-}" = --unpack ]; then
	to=${3%.*}
	[ -e "$to" ] && to=$3.d
	unpack "$3" "$to" $((5000 - $(find "$2" | wc -l))) $(((1048576 - $(du -sk "$2" | cut -f1)) * 1024))
	case $? in
	0) rm -f -- "$3" ;;
	2) : > "$2.big" ;;
	esac
	exit 0
fi

[ $# -eq 1 ] && [ -e "$1" ] || fail "usage: install-cursor.sh FILE|FOLDER"
kaericed=${XDG_STATE_HOME:-$HOME/.local/state}/kaerice/core/bin/kaericed
[ -x "$kaericed" ] || fail "Run ./install.sh first: kaericed is missing."
command -v bsdtar > /dev/null || fail "bsdtar (libarchive) is not installed."

self=$(realpath -- "$0")
file=$(realpath -- "$1")
base=$(basename -- "$file")
name=${base%.*}
name=${name%.tar}

cache=${XDG_CACHE_HOME:-$HOME/.cache}
mkdir -p "$cache"
tmp=$(mktemp -d "$cache/kaerice-cursor.XXXXXX") || exit 1
trap 'chmod -R u+rwX "$tmp"; rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
ulimit -f 1048576 # 512 MB for each file, also where an archive lies about its sizes

in=$tmp/in
if [ -d "$file" ]; then
	[ "$(du -sm -- "$file" | cut -f1)" -le 512 ] || fail "The folder is too big."
	cp -rP -- "$file" "$in"
else
	case $file in
	*.[cC][uU][rR] | *.[aA][nN][iI]) mkdir "$in" && cp -- "$file" "$in/" ;;
	*)
		unpack "$file" "$in" 5000 $((512 * 1024 * 1024))
		case $? in
		0) ;;
		2) fail "The download is too big." ;;
		*) mkdir -p "$in" && : > "$in/$base" ;; # kaericed tells from the name why it cannot be used
		esac
		;;
	esac
fi
for _ in 1 2 3; do
	timeout 120 find "$in" -type f \( -iname '*.zip' -o -iname '*.7z' -o -iname '*.rar' -o -iname '*.cab' \
		-o -iname '*.exe' -o -iname '*.tar' -o -iname '*.tar.*' -o -iname '*.tgz' -o -iname '*.txz' \
		-o -iname '*.deskthemepack' -o -iname '*.themepack' \) -exec sh "$self" --unpack "$in" {} \;
	[ ! -e "$in.big" ] && [ "$(du -sm "$in" | cut -f1)" -le 1024 ] || fail "The download is too big."
done

"$kaericed" install-cursor "$in" "$name"
