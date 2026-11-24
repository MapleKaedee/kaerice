pragma Singleton

import Quickshell
import QtQuick
import qs.services
import "Contrast.js" as Contrast

// Design tokens for kaerice: palette, fonts, card shape. The user's choices come from settings (Theme page).
Singleton {
    // fixed, the same in both modes
    readonly property color ink: "#1c1c1c"         // behind wallpapers and previews, drawn on screenshots
    readonly property color paper: "#f2f0eb"       // text on ink or on a scrim
    readonly property color scrim: "#991c1c1c"     // dim behind modal overlays
    readonly property color scrimLight: "#661c1c1c"

    // by mode
    readonly property bool dark: Settings.get("theme.dark")
    readonly property color face: dark ? "#262422" : paper          // card faces
    readonly property color text: dark ? paper : ink                // text and icons on a face
    readonly property color line: dark ? "#d8d3ca" : ink            // borders, hard shadows, dividers
    readonly property color muted: "#8c8680"                        // secondary text
    readonly property color hover: dark ? "#3a3733" : "#e4dfd6"     // row hover on a face

    readonly property color accent: Settings.get("theme.accent")    // active / selected / alert
    readonly property color accentText: textOn(accent)              // text and icons on accent
    readonly property color highlight: Contrast.pick(face, accent, text) // accent text on a face, unless it is too faint there
    readonly property var accents: ["#e8335a", "#f2622e", "#f5b82e", "#3fa34d", "#1f9e9e", "#2f7de1", "#8b5cf6", "#d946a8"] // presets
    function textOn(fill: color): color { return Contrast.pick(fill, paper, ink); }

    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property string emojiFont: "Noto Color Emoji"

    readonly property int radius: Settings.get("theme.radius")
    readonly property int border: Settings.get("theme.border")
    readonly property int shadow: Settings.get("theme.shadow")      // default hard-shadow offset
    // other sizes are written for the default shape (radius 8, border 3, shadow 4) and scale with the setting
    function corner(px) { return Math.round(px * radius / 8); }
    function stroke(px) { return Math.max(1, Math.round(px * border / 3)); }
    function depth(px) { return Math.round(px * shadow / 4); }
}
