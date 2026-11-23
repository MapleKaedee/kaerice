import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Wallpaper on the background layer of every screen.
// Change: qs -c kaerice ipc call wallpaper set ~/path/to/image.jpg
// The choice is saved to Quickshell's state dir and restored on start.
Scope {
    id: root
    readonly property string fallback: Quickshell.env("HOME") + "/ARCH/Kaenix/collection/wallpaperflare.com_wallpaper.jpg"
    property string source: ""

    FileView {
        id: saved
        path: Quickshell.statePath("wallpaper")
        onLoaded: root.source = text().trim() || root.fallback
        onLoadFailed: root.source = root.fallback
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void {
            const p = path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
            root.source = p;
            saved.setText(p);
        }
        function get(): string { return root.source; }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#1c1c1c" // shown while loading or if the image is missing
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "kaerice-wallpaper"

            Image {
                anchors.fill: parent
                source: root.source ? "file://" + root.source : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width, height) // decode at screen size, not the file's full resolution
            }
        }
    }
}
