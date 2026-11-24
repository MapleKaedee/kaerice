import QtQuick
import qs.config
import qs.services
import qs.components.base

// Wallpaper picker: thumbnails from wallpapers/. Arrows/click to choose, Enter to apply, Esc to close.
// The current wallpaper has an accent frame.
Overlay {
    id: root

    function apply(path) {
        if (!path) return;
        Wallpaper.apply(path);
        Ui.wallpaperPicker = false;
    }

    name: "wallpaper-picker"
    color: Theme.scrim
    visible: Ui.wallpaperPicker
    focusItem: grid
    onDismissed: Ui.wallpaperPicker = false
    onVisibleChanged: if (visible) Wallpaper.scan()

    // start the selection on the current wallpaper
    Connections {
        target: Wallpaper
        function onImagesChanged() {
            grid.currentIndex = Math.max(0, Wallpaper.images.findIndex(i => Wallpaper.base(i) === Wallpaper.base(Wallpaper.source)));
        }
    }

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
                color: Theme.ink
                font.pixelSize: 18; font.bold: true
            }
            Text {
                visible: Wallpaper.images.length === 0
                text: "No images in wallpapers/"
                color: Theme.ink
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
                model: Wallpaper.images

                Keys.onEscapePressed: root.dismissed()
                Keys.onReturnPressed: root.apply(Wallpaper.images[currentIndex])
                Keys.onEnterPressed: root.apply(Wallpaper.images[currentIndex])

                delegate: Item {
                    id: cell
                    required property string modelData
                    required property int index
                    readonly property bool selected: GridView.isCurrentItem
                    readonly property bool active: Wallpaper.base(modelData) === Wallpaper.base(Wallpaper.source)
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Card {
                        x: 6; y: 6
                        width: parent.width - 12
                        height: parent.height - 12
                        offset: cell.selected ? 7 : 4
                        ink: cell.active ? Theme.accent : Theme.ink // current wallpaper gets an accent frame

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
                        onClicked: root.apply(cell.modelData)
                    }
                }
            }
        }
    }
}
