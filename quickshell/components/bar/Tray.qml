import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Tray icons in one card. Left click = activate, right click = app menu.
// Quickshell also acts as the StatusNotifierWatcher, so no extra daemon is needed.
Card {
    id: root
    required property var barWindow

    visible: icons.count > 0
    width: row.implicitWidth + Theme.bar(20) + offset
    height: Theme.bar(38); offset: Theme.bar(Theme.shadow)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.bar(8)

        Repeater {
            id: icons
            model: SystemTray.items

            Item {
                id: slot
                required property SystemTrayItem modelData
                visible: modelData.status !== Status.Passive
                width: visible ? height : 0
                height: Theme.bar(20)

                IconImage {
                    anchors.fill: parent
                    source: slot.modelData.icon
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton || slot.modelData.onlyMenu) {
                            if (!slot.modelData.hasMenu) return;
                            const p = slot.mapToItem(null, 0, BarLayout.atTop ? slot.height + 8 : -8);
                            slot.modelData.display(root.barWindow, p.x, p.y);
                        } else {
                            slot.modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
