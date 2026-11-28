import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Login screen content: wallpaper under a scrim, clock, user, password, session and error cards.
// The clock card repeats the one of components/lock/LockSurface.qml.
Item {
    id: root
    anchors.fill: parent
    property bool sessionsOpen: false

    readonly property string problem: !Greetd.available ? "greetd is not running"
        : !Greeter.user ? "No user to log in" : Greeter.error

    // greeter-sync.sh copies it next to the settings
    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("XDG_CONFIG_HOME") + "/wallpaper"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
    }
    Rectangle { anchors.fill: parent; color: Theme.scrim }
    MouseArea { anchors.fill: parent; enabled: root.sessionsOpen; onClicked: root.sessionsOpen = false }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Card {
            width: 380; height: 160
            offset: Theme.depth(8)
            fill: Theme.accent
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.accentText
                    font.pixelSize: 72; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: Theme.accentText
                    font.pixelSize: 16; font.bold: true
                }
            }
        }

        Card {
            width: 380; height: 72
            offset: Theme.depth(6)
            Row {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 14
                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44; height: 44
                    radius: Theme.radius
                    color: Theme.accent
                    border.width: Theme.border; border.color: Theme.line
                    Image {
                        id: face
                        anchors.fill: parent
                        source: Greeter.user ? "file:///var/lib/AccountsService/icons/" + Greeter.user.user : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(88, 88)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: (Greeter.user?.name ?? "?").charAt(0).toUpperCase()
                        color: Theme.accentText
                        font.pixelSize: 20; font.bold: true
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 58
                    text: Greeter.user?.name ?? ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                }
            }
        }

        Card {
            width: 380; height: 62
            offset: Theme.depth(6)
            Row {
                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xf023) // Nerd Font lock
                    color: Theme.text
                    font.family: Theme.iconFont; font.pixelSize: 20
                }
                TextInput {
                    id: input
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    readOnly: Greeter.busy
                    focus: true
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                    Component.onCompleted: forceActiveFocus()
                    onAccepted: { root.sessionsOpen = false; Greeter.login(text); text = ""; }
                    Keys.onEscapePressed: { if (root.sessionsOpen) root.sessionsOpen = false; else text = ""; }
                    Keys.onUpPressed: Greeter.nextSession(-1)
                    Keys.onDownPressed: Greeter.nextSession(1)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: Greeter.prompt || (Greeter.busy ? "Checking..." : "Password")
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font: input.font
                    }
                }
            }
        }

        // z: its list opens over the cards below
        Card {
            id: sessionCard
            z: 1
            width: 380; height: 52
            offset: Theme.depth(6)
            Row {
                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xf108) // Nerd Font desktop
                    color: Theme.text
                    font.family: Theme.iconFont; font.pixelSize: 18
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    text: Greeter.session?.name ?? "No session"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: 16; font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(root.sessionsOpen ? 0xf0d8 : 0xf0d7) // Nerd Font caret
                    color: Theme.muted
                    font.family: Theme.iconFont; font.pixelSize: 16
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionsOpen = !root.sessionsOpen
            }

            Card {
                visible: root.sessionsOpen
                y: parent.height + 8
                width: sessionCard.width; height: list.height + 12 + offset
                offset: sessionCard.offset
                Column {
                    id: list
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    Repeater {
                        model: Greeter.sessions
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: index === Greeter.sessionIndex
                            width: list.width; height: 40
                            radius: Theme.corner(6)
                            color: current ? Theme.accent : row.containsMouse ? Theme.hover : "transparent"
                            Text {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                                text: modelData.name
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: current ? Theme.accentText : Theme.text
                                font.pixelSize: 16; font.bold: true
                            }
                            MouseArea {
                                id: row
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Greeter.sessionIndex = index; root.sessionsOpen = false; }
                            }
                        }
                    }
                }
            }
        }

        Card {
            visible: problem !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(errText.implicitWidth + 32, 380) + offset
            height: errText.height + 20 + offset
            fill: Theme.accent
            Text {
                id: errText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 380 - 32)
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                text: problem
                textFormat: Text.PlainText
                color: Theme.accentText
                font.pixelSize: 14; font.bold: true
            }
        }
    }
}
