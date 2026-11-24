import QtQuick
import qs.config
import qs.services

// Wallpaper tab of the picker: images on this computer. Arrows or hover choose, Enter or a click applies,
// Del (or the trash button) twice moves the file to the Trash.
FocusScope {
    id: root
    property int cols: 4
    property string armed: "" // path that the next Del removes
    property int keep: -1     // selection to restore after a removal
    signal applied()

    function enter() { forceActiveFocus(); }
    function selectCurrent() { grid.currentIndex = Math.max(0, Wallpaper.images.findIndex(i => Wallpaper.isCurrent(i))); }
    function apply(path) { if (path) { Wallpaper.apply(path); applied(); } }
    function remove(path) {
        if (!path || !Wallpaper.canRemove(path)) return;
        if (armed !== path) { armed = path; disarm.restart(); return; }
        armed = "";
        keep = grid.currentIndex;
        Wallpaper.remove(path);
    }
    Timer { id: disarm; interval: 2000; onTriggered: root.armed = "" }

    Connections {
        target: Wallpaper
        function onImagesChanged() {
            const at = root.keep;
            root.keep = -1;
            Qt.callLater(() => at < 0 ? root.selectCurrent() : grid.currentIndex = Math.min(at, grid.count - 1)); // after the view took the new list
        }
    }

    GridView {
        id: grid
        focus: true
        readonly property string selectedPath: Wallpaper.images[currentIndex] ?? ""
        anchors { fill: parent; bottomMargin: 30 }
        cellWidth: Math.floor(width / root.cols); cellHeight: Math.round(cellWidth * 0.61)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Wallpaper.images
        onCurrentIndexChanged: root.armed = ""

        Keys.onReturnPressed: root.apply(selectedPath)
        Keys.onEnterPressed: root.apply(selectedPath)
        Keys.onDeletePressed: root.remove(selectedPath)

        delegate: Item {
            id: cell
            required property string modelData
            required property int index
            readonly property bool selected: GridView.isCurrentItem
            width: grid.cellWidth; height: grid.cellHeight

            WallpaperThumb {
                path: cell.modelData
                x: 6; y: 6
                width: parent.width - 12; height: parent.height - 12
                offset: Theme.depth(cell.selected ? 7 : 4)
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: root.apply(cell.modelData)
            }
            ThumbButton { // trash
                anchors { top: parent.top; right: parent.right; topMargin: 14; rightMargin: 22 }
                visible: cell.selected && Wallpaper.canRemove(cell.modelData)
                glyph: 0xf1f8
                hot: root.armed === cell.modelData
                onClicked: root.remove(cell.modelData)
            }
        }
    }

    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        elide: Text.ElideMiddle
        text: root.armed ? "Press Del or the button again to move it to the Trash"
            : Wallpaper.error || (Wallpaper.images.length === 0 ? "No images in wallpapers/ or ~/Pictures/Wallpapers" : Wallpaper.base(grid.selectedPath))
        color: Theme.muted
        font.pixelSize: 13; font.bold: true
    }
}
