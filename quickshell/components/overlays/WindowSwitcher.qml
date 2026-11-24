import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Alt+Tab: live previews in most-recently-used order. Hold Alt, Tab / Shift+Tab to move,
// release Alt (or Enter, or click) to switch, Esc to cancel.
// Overview (SUPER+Tab): every window, by workspace, in a grid sized to fill the screen.
// Arrows move, Enter or click focuses, Esc or SUPER+Tab closes.
Overlay {
    id: root
    name: "switcher"
    color: overview ? Theme.scrim : Theme.scrimLight

    readonly property bool overview: Switcher.mode === "overview"
    // columns and card width: switcher uses fixed 280 px cards; overview picks the column count
    // that gives the biggest 16:9 previews inside the screen (capped at 560 px)
    readonly property var grid: {
        const n = Math.max(1, Switcher.windows.length);
        if (!overview) return { cols: n, width: 280 };
        const w = width - 160, h = height - 200, gap = 20, chrome = 24 + 30 + 10 + Theme.depth(8); // padding, label row, spacing, shadow
        let best = { cols: 1, width: 0 };
        for (let c = 1; c <= n; c++) {
            const r = Math.ceil(n / c);
            const cw = Math.min((w - (c - 1) * gap) / c, ((h - (r - 1) * gap) / r - chrome) * 16 / 9 + 32);
            if (cw > best.width) best = { cols: c, width: Math.floor(cw) };
        }
        best.width = Math.min(best.width, 560);
        return best;
    }
    visible: Switcher.open
    focusItem: keys
    onDismissed: Switcher.cancel()

    Item {
        id: keys
        Keys.onEscapePressed: root.dismissed()
        Keys.onReturnPressed: Switcher.commit()
        Keys.onEnterPressed: Switcher.commit()
        Keys.onLeftPressed: Switcher.step(-1)
        Keys.onRightPressed: Switcher.step(1)
        Keys.onUpPressed: if (root.overview) Switcher.step(-root.grid.cols)
        Keys.onDownPressed: if (root.overview) Switcher.step(root.grid.cols)
        // Tab presses go to Hyprland (bound), so only the Alt release reaches us; overview ignores it
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt && !root.overview) Switcher.commit(); }
    }

    Text {
        anchors.centerIn: parent
        visible: Switcher.windows.length === 0
        text: "No windows"
        color: Theme.paper
        font.pixelSize: 20; font.bold: true
    }

    Flow {
        readonly property int cardWidth: root.grid.width
        anchors.centerIn: parent
        width: Math.min(root.grid.cols * (cardWidth + spacing) - spacing, parent.width - 160)
        spacing: 20

        Repeater {
            model: Switcher.windows

            Card {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: Switcher.index === index
                readonly property var entry: DesktopEntries.heuristicLookup(modelData.wayland?.appId ?? "")
                width: parent.cardWidth
                height: frame.height + 62 + Theme.depth(8) // padding, label row, shadow
                offset: Theme.depth(selected ? 8 : 5)
                fill: selected ? Theme.accent : Theme.face

                Column {
                    x: 12; y: 12
                    spacing: 10

                    Rectangle {
                        id: frame
                        width: card.width - card.offset - 24
                        height: root.overview ? Math.round(width * 9 / 16) : 150
                        radius: Theme.corner(4)
                        color: Theme.ink

                        // shown until the preview has a frame (apps hidden off-screen may never send one)
                        IconImage {
                            anchors.centerIn: parent
                            visible: !preview.hasContent
                            implicitSize: Math.min(64, frame.height / 2)
                            source: Quickshell.iconPath(card.entry?.icon ?? "", true) || Quickshell.iconPath("application-x-executable")
                        }
                        ScreencopyView {
                            id: preview
                            anchors.centerIn: parent
                            width: implicitWidth; height: implicitHeight
                            constraintSize: Qt.size(frame.width - 2 * Theme.border, frame.height - 2 * Theme.border)
                            captureSource: root.visible ? card.modelData.wayland : null
                            live: true
                        }
                    }

                    Row {
                        spacing: 8
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            source: Quickshell.iconPath(card.entry?.icon ?? "", true) || Quickshell.iconPath("application-x-executable")
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: frame.width - 28 - wsLabel.width - 8
                            elide: Text.ElideRight
                            text: card.entry?.name ?? card.modelData.wayland?.appId ?? ""
                            color: card.selected ? Theme.accentText : Theme.text
                            font.pixelSize: 14; font.bold: true
                        }
                        Text {
                            id: wsLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.workspace?.name ?? ""
                            color: card.selected ? Theme.accentText : Theme.muted
                            font.pixelSize: 12; font.bold: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { Switcher.index = card.index; Switcher.commit(); }
                }
            }
        }
    }
}
