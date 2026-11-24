import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Lock screen content: wallpaper under a scrim, clock card, password card, error card.
Item {
    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: Wallpaper.source ? "file://" + Wallpaper.source : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
    }
    Rectangle { anchors.fill: parent; color: Theme.scrim }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Card {
            width: 380; height: 160
            offset: 8
            fill: Theme.accent
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.paper
                    font.pixelSize: 72; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: Theme.paper
                    font.pixelSize: 16; font.bold: true
                }
            }
        }

        Card {
            width: 380; height: 62
            offset: 6
            Row {
                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xf023) // Nerd Font lock
                    color: Theme.ink
                    font.family: Theme.iconFont; font.pixelSize: 20
                }
                TextInput {
                    id: input
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    enabled: !Lock.busy
                    focus: true
                    color: Theme.ink
                    font.pixelSize: 18; font.bold: true
                    Component.onCompleted: forceActiveFocus()
                    onAccepted: { Lock.unlock(text); text = ""; }
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: Lock.busy ? "Checking..." : "Password"
                        color: Theme.muted
                        font: input.font
                    }
                }
            }
        }

        Card {
            visible: Lock.error !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(errText.implicitWidth + 32, 380) + offset
            height: errText.height + 20 + offset
            offset: 4
            fill: Theme.accent
            Text {
                id: errText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 380 - 32)
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                text: Lock.error
                color: Theme.paper
                font.pixelSize: 14; font.bold: true
            }
        }
    }
}
