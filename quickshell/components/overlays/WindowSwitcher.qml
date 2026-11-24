import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Alt+Tab: live previews in most-recently-used order. Hold Alt, Tab / Shift+Tab to move,
// release Alt (or Enter, or click) to switch, Esc to cancel.
Overlay {
    id: root
    name: "switcher"
    color: Theme.scrimLight
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
        // Tab presses go to Hyprland (bound), so only the Alt release reaches us
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt) Switcher.commit(); }
    }

    Flow {
        readonly property int cardWidth: 280
        anchors.centerIn: parent
        width: Math.min(Switcher.windows.length * (cardWidth + spacing) - spacing, parent.width - 160)
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
                height: 220
                offset: selected ? 8 : 5
                fill: selected ? Theme.accent : Theme.paper

                Column {
                    x: 12; y: 12
                    spacing: 10

                    Rectangle {
                        id: frame
                        width: card.width - card.offset - 24
                        height: 150
                        radius: 4
                        color: Theme.ink

                        ScreencopyView {
                            anchors.centerIn: parent
                            width: implicitWidth; height: implicitHeight
                            constraintSize: Qt.size(frame.width - 6, frame.height - 6)
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
                            color: card.selected ? Theme.paper : Theme.ink
                            font.pixelSize: 14; font.bold: true
                        }
                        Text {
                            id: wsLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.workspace?.name ?? ""
                            color: card.selected ? Theme.paper : Theme.muted
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
