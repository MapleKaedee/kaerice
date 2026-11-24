import Quickshell
import QtQuick

// Top bar: workspaces + window title on the left, status cards on the right,
// media centered in the free space between them (it shrinks its title to fit, hides below a minimum).
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 52
    color: "transparent"

    // first child: drawn behind every card
    Visualizer {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
    }

    Row {
        id: leftRow
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8

        Workspaces {}
        WindowTitle {}
    }

    Item {
        id: middle
        anchors { left: leftRow.right; right: rightRow.left; leftMargin: 8; rightMargin: 8; top: parent.top; bottom: parent.bottom }

        MediaCard {
            anchors.centerIn: parent
            maxTextWidth: Math.min(260, middle.width - 120) // 120: controls, padding, shadow
            visible: maxTextWidth >= 60
        }
    }

    Row {
        id: rightRow
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8

        PrivacyCard {}
        Tray { barWindow: bar }
        NetworkCard {}
        VolumeCard {}
        BrightnessCard {}
        BatteryCard {}
        NotificationBell {}
        DistroCard {}
        ClockCard {}
    }
}
