pragma Singleton

import Quickshell
import QtQuick

// Design tokens for kaerice. Change the palette, fonts or card shape here, not in components.
Singleton {
    readonly property color ink: "#1c1c1c"         // borders, hard shadows, text on paper
    readonly property color paper: "#f2f0eb"       // card faces, text on accent
    readonly property color accent: "#e8335a"      // active / selected / alert
    readonly property color muted: "#8c8680"       // placeholders
    readonly property color hover: "#e4dfd6"       // row hover on paper
    readonly property color scrim: "#991c1c1c"     // dim behind modal overlays
    readonly property color scrimLight: "#661c1c1c"

    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int radius: 8
    readonly property int border: 3
    readonly property int shadow: 4                // default hard-shadow offset
}
