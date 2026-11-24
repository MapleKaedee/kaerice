import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Wallpaper.source on the background layer of every screen.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.ink // shown while loading or if the image is missing
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "kaerice-wallpaper"

            Image {
                anchors.fill: parent
                source: Wallpaper.source ? "file://" + Wallpaper.source : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width, height) // decode at screen size, not the file's full resolution
            }
        }
    }
}
