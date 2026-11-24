import QtQuick
import qs.config
import qs.services
import qs.components.base

// Active player: cover, title, artist, controls, progress. "Nothing playing" otherwise.
Card {
    id: root
    readonly property var player: Media.player
    readonly property bool hasLength: !!player?.lengthSupported && player.length > 0

    function time(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // MPRIS position is not pushed; re-read it every second while playing
    Timer {
        interval: 1000; repeat: true
        running: root.visible && Media.playing
        onTriggered: root.player?.positionChanged()
    }

    Row {
        anchors { fill: parent; margins: 14 }
        spacing: 14

        // cover (falls back to a music glyph)
        Rectangle {
            width: height; height: parent.height
            radius: 4
            color: Theme.ink
            Image {
                id: art
                anchors { fill: parent; margins: 3 }
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(208, 208)
            }
            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: String.fromCodePoint(0xf001) // music
                color: Theme.paper
                font.family: Theme.iconFont; font.pixelSize: 36
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - parent.height - parent.spacing
            spacing: 6

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.active ? Media.title : "Nothing playing"
                color: Theme.ink
                font.pixelSize: 16; font.bold: true
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: Media.active
                text: Media.artist
                color: Theme.muted
                font.pixelSize: 13; font.bold: true
            }

            Row {
                visible: Media.active
                spacing: 22
                topPadding: 4
                // Nerd Font: backward-step f048, play f04b, pause f04c, forward-step f051
                IconButton {
                    font.pixelSize: 20
                    text: String.fromCodePoint(0xf048)
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: Media.previous()
                }
                IconButton {
                    font.pixelSize: 20
                    text: String.fromCodePoint(Media.playing ? 0xf04c : 0xf04b)
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: Media.togglePlaying()
                }
                IconButton {
                    font.pixelSize: 20
                    text: String.fromCodePoint(0xf051)
                    enabled: root.player?.canGoNext ?? false
                    onClicked: Media.next()
                }
            }

            Row {
                visible: root.hasLength
                width: parent.width
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 84 - parent.spacing
                    height: 10
                    radius: 3
                    color: Theme.paper
                    border.width: 2; border.color: Theme.ink
                    Rectangle {
                        x: 2; y: 2
                        height: parent.height - 4
                        width: (parent.width - 4) * Math.min(1, root.hasLength ? (root.player?.position ?? 0) / root.player.length : 0)
                        radius: 1
                        color: Theme.accent
                    }
                }
                Text {
                    width: 84
                    horizontalAlignment: Text.AlignRight
                    text: root.time(root.player?.position ?? 0) + " / " + root.time(root.player?.length ?? 0)
                    color: Theme.muted
                    font.pixelSize: 12; font.bold: true
                }
            }
        }
    }
}
