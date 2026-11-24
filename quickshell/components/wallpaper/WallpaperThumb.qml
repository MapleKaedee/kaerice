import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Thumbnail of a wallpaper: a local file (path), or source when it is not local. The current wallpaper has an accent frame.
Card {
    id: root
    property string path
    property string source: path ? "file://" + path : ""
    readonly property bool active: path !== "" && Wallpaper.isCurrent(path)
    line: active ? Theme.accent : Theme.line

    ClippingRectangle {
        anchors { fill: parent; margins: Theme.border }
        radius: Math.max(0, Theme.radius - Theme.border)
        color: "transparent"
        Image {
            anchors.fill: parent
            source: root.source
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
