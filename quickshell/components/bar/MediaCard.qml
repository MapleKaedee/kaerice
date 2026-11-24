import QtQuick
import qs.config
import qs.services
import qs.components.base

// Active MPRIS track: prev / play-pause / next + "Title - Artist". Hidden when nothing plays.
Card {
    id: root
    visible: Media.active
    width: row.implicitWidth + 28 + offset
    height: 38

    component Button: Text {
        id: btn
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        color: !enabled ? Theme.muted : area.containsMouse ? Theme.accent : Theme.ink
        font.family: Theme.iconFont
        font.pixelSize: 15
        MouseArea {
            id: area
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true // disabled with the Text (Item.enabled propagates)
            onClicked: btn.clicked()
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        // Nerd Font: backward-step f048, play f04b, pause f04c, forward-step f051
        Button {
            text: String.fromCodePoint(0xf048)
            enabled: Media.active && Media.player.canGoPrevious
            onClicked: Media.previous()
        }
        Button {
            text: String.fromCodePoint(Media.playing ? 0xf04c : 0xf04b)
            enabled: Media.active && Media.player.canTogglePlaying
            onClicked: Media.togglePlaying()
        }
        Button {
            text: String.fromCodePoint(0xf051)
            enabled: Media.active && Media.player.canGoNext
            onClicked: Media.next()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            text: Media.artist ? Media.title + " - " + Media.artist : Media.title
            color: Media.playing ? Theme.ink : Theme.muted
            font.pixelSize: 14; font.bold: true
        }
    }
}
