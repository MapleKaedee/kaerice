import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

// Tray icons in one card. Left click = activate, right click = app menu.
// Quickshell also acts as the StatusNotifierWatcher, so no extra daemon is needed.
Card {
    id: root
    required property var barWindow

    visible: icons.count > 0
    width: row.implicitWidth + 20 + offset
    height: 38

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            id: icons
            model: SystemTray.items

            Item {
                id: slot
                required property SystemTrayItem modelData
                visible: modelData.status !== Status.Passive
                width: visible ? 20 : 0
                height: 20

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
                            const p = slot.mapToItem(null, 0, slot.height + 8);
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
