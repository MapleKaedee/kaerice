import QtQuick
import qs.config
import qs.services
import qs.components.base

// Wallpaper picker: images on this computer, or Wallhaven. Tab switches between them, Esc closes.
Overlay {
    id: root
    name: "wallpaper-picker"
    color: Theme.scrim
    visible: Ui.wallpaperPicker
    focusItem: local
    onDismissed: Ui.wallpaperPicker = false
    onVisibleChanged: {
        if (!visible) return;
        Wallpaper.scan();
        local.selectCurrent();
        show("local");
    }

    property string tab: "local"
    readonly property int cols: Math.max(1, Math.min(4, Math.floor((width - 100) / 256)))
    function show(t) {
        tab = t;
        (t === "local" ? local : wallhaven).enter();
    }

    Card {
        id: panel
        // on the panel itself, so keys a focused field does not use still arrive here
        Keys.onEscapePressed: root.dismissed()
        Keys.onTabPressed: root.show(root.tab === "local" ? "wallhaven" : "local")
        anchors.centerIn: parent
        width: root.cols * 256 + 24 + offset
        height: Math.min(760, parent.height - 80)
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Choice {
            id: tabs
            x: 12; y: 12
            options: [{ value: "local", label: "Wallpaper" }, { value: "wallhaven", label: "Wallhaven" }]
            value: root.tab
            onPicked: v => root.show(v)
        }
        IconButton {
            anchors { right: parent.right; rightMargin: 18; verticalCenter: tabs.verticalCenter }
            text: String.fromCodePoint(0xf00d) // xmark
            font.pixelSize: 18
            onClicked: root.dismissed()
        }

        Item {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 62; bottomMargin: 12 }
            LocalWallpapers {
                id: local
                anchors.fill: parent
                visible: root.tab === "local"
                cols: root.cols
                onApplied: root.dismissed()
            }
            WallhavenBrowser {
                id: wallhaven
                anchors.fill: parent
                visible: root.tab === "wallhaven"
                cols: root.cols
            }
        }
    }
}
