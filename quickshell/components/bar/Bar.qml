import Quickshell
import QtQuick

// Top bar: workspaces + window title on the left, media in the center, status cards on the right.
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 52
    color: "transparent"

    Row {
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8

        Workspaces {}
        WindowTitle {}
    }

    MediaCard {
        anchors.centerIn: parent
    }

    Row {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: 8

        Tray { barWindow: bar }
        NetworkCard {}
        VolumeCard {}
        BrightnessCard {}
        BatteryCard {}
        NotificationBell {}
        ClockCard {}
    }
}
