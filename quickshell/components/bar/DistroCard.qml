import Quickshell.Io
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Distro logo (ID, then ID_LIKE, from /etc/os-release; Tux if unknown). Click opens the control center.
Card {
    id: root
    width: 40 + offset; height: 38
    fill: Ui.controlCenter ? Theme.accent : Theme.paper

    // Nerd Font font-logos code points
    readonly property var logos: ({
        alpine: 0xf300, arch: 0xf303, artix: 0xf31f, debian: 0xf306, endeavouros: 0xf322, fedora: 0xf30a,
        gentoo: 0xf30d, linuxmint: 0xf30e, manjaro: 0xf312, nixos: 0xf313, opensuse: 0xf314, pop: 0xf32a,
        ubuntu: 0xf31b, void: 0xf32e
    })
    function field(key) { return (osRelease.text().match(new RegExp("^" + key + "=\"?([^\"\\n]*)", "m")) ?? [])[1] ?? ""; }
    readonly property int glyph: {
        const ids = [field("ID")].concat(field("ID_LIKE").split(" ")).map(id => id.replace(/-.*/, ""));
        return ids.map(id => logos[id]).find(g => g) ?? 0xf17c;
    }

    FileView { id: osRelease; path: "/etc/os-release" }

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(root.glyph)
        color: Ui.controlCenter ? Theme.paper : Theme.ink
        font.family: Theme.iconFont; font.pixelSize: 19
    }

    MouseArea { anchors.fill: parent; onClicked: Ui.controlCenter = !Ui.controlCenter }
}
