import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Keybind cheat sheet: every Hyprland bind from `hyprctl binds -j` (read on open), grouped by its
// "Group: action" description (hypr/conf/binds*.lua). Binds sharing an action show on one row.
// Type to filter, Up/Down to scroll, Esc closes.
Overlay {
    id: root
    name: "keybinds"
    color: Theme.scrimLight
    visible: Ui.keybinds
    focusItem: search
    onDismissed: Ui.keybinds = false
    onVisibleChanged: if (visible) { search.text = ""; reader.running = true; }

    property var rows: [] // { group, action, combos: [[key, ...], ...] }
    readonly property var groupOrder: ["Shell", "Apps", "Window", "Focus", "Layout", "Workspace", "Scratchpad",
                                       "Monitor", "Screenshot", "Media", "Audio", "Display"]
    readonly property var matches: {
        const q = search.text.trim().toLowerCase();
        return !q ? rows : rows.filter(r => (r.group + " " + r.action + " " + r.combos.map(c => c.join(" ")).join(" ")).toLowerCase().includes(q));
    }
    // matches with a { header } entry before each group
    readonly property var shown: {
        const out = [];
        let group = "";
        for (const r of matches) {
            if (r.group !== group) { group = r.group; out.push({ header: group }); }
            out.push(r);
        }
        return out;
    }

    readonly property var keyNames: ({
        left: "←", right: "→", up: "↑", down: "↓", Return: "Enter", space: "Space", semicolon: ";", slash: "/", comma: ",",
        period: ".", bracketleft: "[", bracketright: "]", minus: "-", equal: "=", Page_Up: "PgUp", Page_Down: "PgDn",
        "mouse:272": "LMB", "mouse:273": "RMB", mouse_down: "Wheel ↓", mouse_up: "Wheel ↑",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol -", XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioPrev: "Prev", XF86AudioNext: "Next",
        Caps_Lock: "Caps Lock", Num_Lock: "Num Lock", Alt_L: "Left Alt", Alt_R: "Right Alt", XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright -"
    })

    function parse(json) {
        const mods = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];
        const byAction = {};
        const out = [];
        for (const b of JSON.parse(json)) {
            // binds without a description fall back to the dispatcher name, e.g. HL.Dispatcher(focus) -> focus
            const desc = b.description || b.dispatcher.replace(/^HL\.Dispatcher\((.*)\)$/, "$1");
            const i = desc.indexOf(": ");
            const group = i > 0 ? desc.slice(0, i) : "Other", action = i > 0 ? desc.slice(i + 2) : desc;
            // Hyprland adds the key's own mod to a modifier key bind (Alt_L: ALT)
            const combo = mods.filter(m => b.modmask & m[0] && !b.key.toUpperCase().startsWith(m[1]))
                .map(m => m[1]).concat([keyNames[b.key] ?? b.key]);
            const id = group + "\n" + action;
            if (!byAction[id]) { byAction[id] = { group: group, action: action, combos: [] }; out.push(byAction[id]); }
            byAction[id].combos.push(combo);
        }
        const rank = g => { const r = groupOrder.indexOf(g); return r < 0 ? groupOrder.length : r; };
        rows = out.sort((a, b) => rank(a.group) - rank(b.group) || a.action.localeCompare(b.action));
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { id: out; onStreamFinished: root.parse(out.text) }
    }

    component Keycap: Rectangle {
        property alias text: label.text
        width: label.implicitWidth + 14; height: 24
        radius: Theme.corner(4)
        color: Theme.face
        border.width: Theme.stroke(2); border.color: Theme.line
        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 11; font.bold: true
        }
    }

    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.1
        width: 760
        height: col.implicitHeight + 24 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Column {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 12

            Card {
                width: parent.width
                height: 50
                offset: Theme.depth(3)

                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                    Keys.onEscapePressed: root.dismissed()
                    Keys.onUpPressed: list.flick(0, 900)
                    Keys.onDownPressed: list.flick(0, -900)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search keybinds…"
                        color: Theme.muted
                        font: search.font
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, root.height * 0.8 - 120)
                clip: true
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool header: modelData.header !== undefined
                    width: list.width
                    height: header ? 34 : Math.max(32, combos.implicitHeight + 8)

                    Text {
                        visible: row.header
                        anchors.bottom: parent.bottom
                        bottomPadding: 4
                        text: (row.modelData.header ?? "").toUpperCase()
                        color: Theme.highlight
                        font.pixelSize: 13; font.bold: true
                    }

                    Text {
                        visible: !row.header
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: parent.width - combos.width - 16
                        elide: Text.ElideRight
                        text: row.header ? "" : row.modelData.action.charAt(0).toUpperCase() + row.modelData.action.slice(1)
                        color: Theme.text
                        font.pixelSize: 14; font.bold: true
                    }

                    // every combo for this action, "/" between them. Right-to-left flow, so the model is
                    // reversed and each combo but the rightmost carries a trailing "/".
                    Flow {
                        id: combos
                        visible: !row.header
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 440
                        layoutDirection: Qt.RightToLeft
                        spacing: 6

                        Repeater {
                            model: (row.modelData.combos ?? []).slice().reverse()
                            Row {
                                required property var modelData
                                required property int index
                                id: combo
                                spacing: 4
                                Repeater {
                                    model: combo.modelData
                                    Keycap { required property string modelData; text: modelData }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: combo.index > 0
                                    text: "/"
                                    color: Theme.muted
                                    font.pixelSize: 13; font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: root.matches.length + " of " + root.rows.length + " actions  ·  from hypr/conf/binds*.lua descriptions"
                color: Theme.muted
                font.pixelSize: 12; font.bold: true
            }
        }
    }
}
