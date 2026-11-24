pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Distro name and logo (from /etc/os-release) and version numbers. refresh() reads the versions (settings > About).
Singleton {
    id: root
    readonly property string distro: field("PRETTY_NAME") || field("ID")
    // Nerd Font logo: ID, then ID_LIKE; Tux if unknown
    readonly property int logo: {
        const ids = [field("ID")].concat(field("ID_LIKE").split(" ")).map(id => id.replace(/-.*/, ""));
        return ids.map(id => logos[id]).find(g => g) ?? 0xf17c;
    }
    property var versions: ({}) // kernel, hyprland, quickshell, kaerice

    // Nerd Font font-logos code points
    readonly property var logos: ({
        alpine: 0xf300, arch: 0xf303, artix: 0xf31f, debian: 0xf306, endeavouros: 0xf322, fedora: 0xf30a,
        gentoo: 0xf30d, linuxmint: 0xf30e, manjaro: 0xf312, nixos: 0xf313, opensuse: 0xf314, pop: 0xf32a,
        ubuntu: 0xf31b, void: 0xf32e
    })
    function field(key) { return (osRelease.text().match(new RegExp("^" + key + "=\"?([^\"\\n]*)", "m")) ?? [])[1] ?? ""; }

    function refresh() { reader.running = true; }

    FileView { id: osRelease; path: "/etc/os-release" }

    // key=value lines; "+" after the commit means uncommitted changes. git -C, not cd: shellDir is a symlink and the
    // shell would resolve ".." next to the link instead of in the repo
    Process {
        id: reader
        command: ["sh", "-c", `
            echo "kernel=$(uname -r)"
            echo "hyprland=$(hyprctl version -j | jq -r .version)"
            echo "quickshell=$(qs --version | grep -oE '[0-9]+(\\.[0-9]+)+' | head -1)"
            echo "kaerice=$(git -C "$1" log -1 --format='%h (%cs)')$([ -n "$(git -C "$1" status --porcelain)" ] && echo ' +')"`,
            "sh", Quickshell.shellDir + "/.."]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                const v = {};
                for (const line of out.text.trim().split("\n")) v[line.split("=")[0]] = line.slice(line.indexOf("=") + 1);
                root.versions = v;
            }
        }
    }
}
