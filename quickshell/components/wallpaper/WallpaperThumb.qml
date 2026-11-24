import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Thumbnail of a wallpaper file; the current wallpaper has an accent frame.
Card {
    id: root
    required property string path
    readonly property bool active: Wallpaper.base(path) === Wallpaper.base(Wallpaper.source)
    line: active ? Theme.accent : Theme.line

    ClippingRectangle {
        anchors { fill: parent; margins: Theme.border }
        radius: Math.max(0, Theme.radius - Theme.border)
        color: "transparent"
        Image {
            anchors.fill: parent
            source: "file://" + root.path
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
