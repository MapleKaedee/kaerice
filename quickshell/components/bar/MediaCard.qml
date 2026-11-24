import QtQuick
import qs.config
import qs.services
import qs.components.base

// Active MPRIS track: prev / play-pause / next + "Title - Artist"; "No media playing" otherwise.
// Click the card (outside the buttons) to open the dashboard.
Card {
    id: root
    width: row.implicitWidth + 28 + offset
    height: 38
    property int maxTextWidth: 260 // title width limit, set by the bar to fit the free space

    MouseArea { anchors.fill: parent; onClicked: Ui.dashboard = !Ui.dashboard }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Text { // Nerd Font music, shown instead of the controls when nothing plays
            anchors.verticalCenter: parent.verticalCenter
            visible: !Media.active
            text: String.fromCodePoint(0xf001)
            color: Theme.muted
            font.family: Theme.iconFont; font.pixelSize: 15
        }
        // Nerd Font: backward-step f048, play f04b, pause f04c, forward-step f051
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.active
            text: String.fromCodePoint(0xf048)
            enabled: Media.player?.canGoPrevious ?? false
            onClicked: Media.previous()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.active
            text: String.fromCodePoint(Media.playing ? 0xf04c : 0xf04b)
            enabled: Media.player?.canTogglePlaying ?? false
            onClicked: Media.togglePlaying()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.active
            text: String.fromCodePoint(0xf051)
            enabled: Media.player?.canGoNext ?? false
            onClicked: Media.next()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            elide: Text.ElideRight
            text: !Media.active ? "No media playing" : Media.artist ? Media.title + " - " + Media.artist : Media.title
            color: Media.playing ? Theme.text : Theme.muted
            font.pixelSize: 14; font.bold: true
        }
    }
}
