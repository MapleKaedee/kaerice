import Quickshell
import QtQuick

// Top bar: workspaces on the left, media in the center, status cards on the right.
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 52
    color: "transparent"

    Workspaces {
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
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
