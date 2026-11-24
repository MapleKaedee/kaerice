import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Bar: edge, size, monitor, and which cards are where. A card is selected by a click or Tab; Left/Right move it
// (past the end of a section into the next one), Space hides or shows it. The buttons do the same.
Column {
    id: root
    spacing: 14
    property string selected: ""
    property bool focused: false  // a card has the keyboard focus
    property bool refocus: false  // every card is made anew after a change: the selected one takes the focus back

    // Nerd Font: th-large, window-maximize, music, eye, ellipsis, wifi, volume, sun, battery, bell, sliders, clock
    readonly property var cards: ({
        workspaces: { label: "Workspaces", glyph: 0xf009 }, title: { label: "Title", glyph: 0xf2d0 }, media: { label: "Media", glyph: 0xf001 },
        privacy: { label: "Privacy", glyph: 0xf06e }, tray: { label: "Tray", glyph: 0xf141 }, network: { label: "Network", glyph: 0xf1eb },
        volume: { label: "Volume", glyph: 0xf028 }, brightness: { label: "Brightness", glyph: 0xf185 }, battery: { label: "Battery", glyph: 0xf240 },
        notifications: { label: "Notifications", glyph: 0xf0f3 }, control: { label: "Control center", glyph: 0xf1de }, clock: { label: "Clock", glyph: 0xf017 }
    })
    readonly property bool selectedHidden: BarLayout.hidden.includes(selected)

    function move(by) { refocus = focused; BarLayout.move(selected, by); }
    function toggle() { refocus = focused; BarLayout.toggle(selected); }

    SettingRow {
        label: "Position"
        Choice {
            options: [{ value: "top", label: "Top" }, { value: "bottom", label: "Bottom" }]
            value: Settings.get("bar.position")
            onPicked: v => Settings.set("bar.position", v)
        }
    }
    SettingRow {
        label: "Size"
        hint: "Height of a card"
        Stepper {
            values: [28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48]
            value: Settings.get("bar.size")
            format: v => v + " px"
            onPicked: v => Settings.set("bar.size", v)
        }
    }
    SettingRow {
        id: monitor
        readonly property var names: Quickshell.screens.map(s => s.name)
        readonly property string chosen: Settings.get("bar.monitor")
        label: "Monitor"
        hint: chosen === "all" || names.includes(chosen) ? "" : chosen + " is not connected, so the bar is on every monitor."
        Choice {
            options: ["all"].concat(monitor.names).map(n => ({ value: n, label: n === "all" ? "All" : n }))
            value: monitor.chosen
            onPicked: v => Settings.set("bar.monitor", v)
        }
    }

    SettingRow {
        label: "Cards"
        hint: "Privacy and Tray show only when in use"
        Row {
            spacing: 8
            TextButton { // chevron-left
                glyph: 0xf053; label: "Earlier"
                enabled: BarLayout.canMove(root.selected, -1)
                onClicked: root.move(-1)
            }
            TextButton { // chevron-right
                glyph: 0xf054; label: "Later"
                enabled: BarLayout.canMove(root.selected, 1)
                onClicked: root.move(1)
            }
            TextButton { // eye, eye-slash
                glyph: root.selectedHidden ? 0xf06e : 0xf070; label: root.selectedHidden ? "Show" : "Hide"
                enabled: root.selected !== ""
                onClicked: root.toggle()
            }
        }
    }
    Column { // close together: the whole page fits without scrolling
        width: parent.width
        spacing: 4
        Repeater {
            model: BarLayout.names.concat("hidden")
            Row {
                id: group
                required property string modelData
                width: root.width
                spacing: 12
                Text {
                    width: 64; height: 38
                    verticalAlignment: Text.AlignVCenter
                    text: group.modelData.charAt(0).toUpperCase() + group.modelData.slice(1)
                    color: Theme.muted
                    font.pixelSize: 13; font.bold: true
                }
                Flow {
                    width: parent.width - 64 - parent.spacing
                    spacing: 8
                    Repeater {
                        model: group.modelData === "hidden" ? BarLayout.hidden : BarLayout.sections[group.modelData]
                        TextButton {
                            id: card
                            required property string modelData
                            glyph: root.cards[modelData].glyph
                            label: root.cards[modelData].label
                            hot: root.selected === modelData
                            onActiveFocusChanged: { root.focused = activeFocus; if (activeFocus) root.selected = modelData; }
                            onClicked: forceActiveFocus()
                            Keys.onLeftPressed: root.move(-1)
                            Keys.onRightPressed: root.move(1)
                            Keys.onSpacePressed: root.toggle()
                            Component.onCompleted: if (root.refocus && root.selected === modelData) { root.refocus = false; forceActiveFocus(); }
                        }
                    }
                }
            }
        }
    }
}
