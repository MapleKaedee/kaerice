pragma Singleton

import Quickshell
import QtQuick
import "BarLayout.js" as Layout

// The bar's edge, height, monitors and cards (settings, Bar page), and where the panels opened from it go.
Singleton {
    id: root
    readonly property bool atTop: Settings.get("bar.position") === "top"
    readonly property int height: Settings.get("bar.size") + 14 // of the bar's window
    readonly property var screens: Layout.screens(Quickshell.screens, Settings.get("bar.monitor"))
    readonly property string cards: Settings.get("bar.cards")
    readonly property var names: Layout.sections             // left, center, right
    readonly property var sections: Layout.parse(cards)      // name -> card ids
    readonly property var hidden: Layout.hidden(cards)       // card ids

    function canMove(id, by) { return Layout.canMove(cards, id, by); }
    function move(id, by) { Settings.set("bar.cards", Layout.move(cards, id, by)); }
    function toggle(id) { Settings.set("bar.cards", Layout.toggle(cards, id)); }

    // place of a panel (its size, the screen's size): at the bar, on the side of the card that opens it
    function panelX(id, width, full) {
        const s = Layout.section(cards, id);
        return s === "left" ? 14 : s === "center" ? Math.round((full - width) / 2) : full - width - 14;
    }
    function panelY(height, full) { return atTop ? root.height + 8 : full - root.height - 8 - height; }
}
