import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Wallpaper on the background layer of every screen, plus a picker.
// Picker (SUPER+Y): qs -c kaerice ipc call wallpaper pick   Arrows/click to choose, Enter to apply, Esc to close.
// Set directly:     qs -c kaerice ipc call wallpaper set ~/path/to/image.jpg
// The choice is saved to Quickshell's state dir and restored on start.
// Images come from the repo's wallpapers/ folder (shellDir is the quickshell/ symlink, so ".." is the repo).
Scope {
    id: root
    readonly property string dir: Quickshell.shellDir + "/../wallpapers"
    readonly property string fallback: dir + "/wallhaven-gwq1w3_1920x1080.png"
    property string source: ""
    property bool picking: false
    property var images: []

    function apply(path) {
        const p = path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
        root.source = p;
        saved.setText(p);
    }

    // shortcut: "current wallpaper" is matched by file name, since saved paths may be canonical or go through the symlink
    function base(p) { return p.split("/").pop(); }

    FileView {
        id: saved
        path: Quickshell.statePath("wallpaper")
        onLoaded: root.source = text().trim() || root.fallback
        onLoadFailed: root.source = root.fallback
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { root.apply(path); }
        function get(): string { return root.source; }
        function pick(): void { root.picking = !root.picking; }
    }

    // lists the folder each time the picker opens, so newly added images show up
    Process {
        id: scan
        command: ["find", "-L", root.dir + "/", "-maxdepth", "1", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")",
                  "-exec", "realpath", "{}", "+"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                root.images = scanOut.text.split("\n").filter(l => l).sort();
                grid.currentIndex = Math.max(0, root.images.findIndex(i => root.base(i) === root.base(root.source)));
            }
        }
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

    PanelWindow {
        visible: root.picking
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#991c1c1c"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-wallpaper-picker"

        onVisibleChanged: {
            if (!visible) return;
            scan.running = true;
            grid.forceActiveFocus();
        }

        // click on the backdrop closes
        MouseArea { anchors.fill: parent; onClicked: root.picking = false }

        Card {
            anchors.centerIn: parent
            width: Math.max(grid.width, 300) + 24 + offset
            height: col.implicitHeight + 24 + offset
            offset: 6

            MouseArea { anchors.fill: parent } // swallow clicks inside the card

            Column {
                id: col
                x: 12; y: 12
                spacing: 12

                Text {
                    text: "Wallpaper"
                    color: "#1c1c1c"
                    font.pixelSize: 18; font.bold: true
                }
                Text {
                    visible: root.images.length === 0
                    text: "No images in wallpapers/"
                    color: "#1c1c1c"
                    opacity: 0.75
                    font.pixelSize: 13
                }

                GridView {
                    id: grid
                    readonly property int cols: Math.max(1, Math.min(3, count))
                    width: cols * cellWidth
                    height: Math.min(Math.ceil(count / cols), 3) * cellHeight
                    cellWidth: 256
                    cellHeight: 156
                    visible: count > 0
                    clip: true
                    focus: true
                    model: root.images

                    Keys.onEscapePressed: root.picking = false
                    Keys.onReturnPressed: { root.apply(root.images[currentIndex]); root.picking = false; }
                    Keys.onEnterPressed: { root.apply(root.images[currentIndex]); root.picking = false; }

                    delegate: Item {
                        id: cell
                        required property string modelData
                        required property int index
                        readonly property bool selected: GridView.isCurrentItem
                        readonly property bool active: root.base(modelData) === root.base(root.source)
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Card {
                            x: 6; y: 6
                            width: parent.width - 12
                            height: parent.height - 12
                            offset: cell.selected ? 7 : 4
                            ink: cell.active ? "#e8335a" : "#1c1c1c" // current wallpaper gets a red frame

                            Image {
                                anchors { fill: parent; margins: 3 }
                                source: "file://" + cell.modelData
                                sourceSize: Qt.size(width, height)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: grid.currentIndex = cell.index
                            onClicked: { root.apply(cell.modelData); root.picking = false; }
                        }
                    }
                }
            }
        }
    }
}
