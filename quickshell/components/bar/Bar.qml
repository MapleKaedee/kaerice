import Quickshell
import QtQuick
import qs.services

// One bar per chosen monitor, at the top or bottom. Which cards, in which order and section comes from settings
// (BarLayout). The center section is centered in the free space between the other two; the media card shrinks its
// title to fit and hides below a minimum.
Variants {
    model: BarLayout.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData
        anchors { top: BarLayout.atTop; bottom: !BarLayout.atTop; left: true; right: true }
        implicitHeight: BarLayout.height
        color: "transparent"

        // first child: drawn behind every card
        Visualizer {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
        }

        Row {
            id: leftRow
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
        }
        Item {
            anchors { left: leftRow.right; right: rightRow.left; leftMargin: 8; rightMargin: 8; top: parent.top; bottom: parent.bottom }
            Row { id: centerRow; anchors.centerIn: parent; spacing: 8 }
        }
        Row {
            id: rightRow
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
        }

        // every card exists once and is moved into its row; hidden ones stay here
        Item {
            id: shelf
            visible: false
            Workspaces { id: workspaces }
            WindowTitle { id: title }
            MediaCard {
                id: media
                maxTextWidth: Math.min(260, bar.free - 120) // 120: controls, padding, shadow
                visible: maxTextWidth >= 60
            }
            PrivacyCard { id: privacy }
            Tray { id: tray; barWindow: bar }
            NetworkCard { id: network }
            VolumeCard { id: volume }
            BrightnessCard { id: brightness }
            BatteryCard { id: battery }
            NotificationBell { id: notifications }
            DistroCard { id: control }
            ClockCard { id: clock }
        }
        readonly property var rows: ({ left: leftRow, center: centerRow, right: rightRow })
        readonly property var cards: ({
            workspaces: workspaces, title: title, media: media, privacy: privacy, tray: tray, network: network, volume: volume,
            brightness: brightness, battery: battery, notifications: notifications, control: control, clock: clock
        })
        readonly property real free: { // width left for the media card
            let used = 2 * 14;
            for (const id in cards) if (id !== "media" && cards[id].visible) used += cards[id].width + 8;
            return width - used;
        }

        function place() {
            for (const id in cards) cards[id].parent = shelf;
            for (const name of BarLayout.names) for (const id of BarLayout.sections[name]) cards[id].parent = rows[name];
        }
        Component.onCompleted: place()
        Connections {
            target: BarLayout
            function onSectionsChanged() { bar.place(); }
        }
    }
}
