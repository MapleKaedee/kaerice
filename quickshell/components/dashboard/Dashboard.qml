import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Dashboard (center): profile, clock, media | system usage, calendar. Esc or backdrop closes.
Overlay {
    id: root
    name: "dashboard"
    color: Theme.scrimLight
    visible: Ui.dashboard
    onDismissed: Ui.dashboard = false
    onVisibleChanged: if (visible) cal.reset()

    readonly property int colWidth: 400
    readonly property string user: Quickshell.env("USER")
    // avatar candidates, first readable wins; falls back to the initial
    readonly property var faces: [Quickshell.env("HOME") + "/.face", "/var/lib/AccountsService/icons/" + user]
    property int faceIndex: 0

    function uptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return "up " + (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    MouseArea { anchors.fill: columns } // swallow clicks on and between the cards

    Row {
        id: columns
        anchors.centerIn: parent
        spacing: 20

        Column {
            spacing: 20

            // profile
            Card {
                width: root.colWidth; height: 104
                Row {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 16

                    ClippingRectangle {
                        width: 68; height: 68
                        radius: Theme.radius
                        color: Theme.accent
                        border.width: Theme.border; border.color: Theme.ink
                        Image {
                            id: face
                            anchors.fill: parent
                            source: root.faceIndex < root.faces.length ? "file://" + root.faces[root.faceIndex] : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(136, 136)
                            onStatusChanged: if (status === Image.Error) root.faceIndex++
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: root.user.charAt(0).toUpperCase()
                            color: Theme.paper
                            font.pixelSize: 30; font.bold: true
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            text: root.user
                            color: Theme.ink
                            font.pixelSize: 20; font.bold: true
                        }
                        Text {
                            text: SysStats.host + (SysStats.uptime ? "  ·  " + root.uptime(SysStats.uptime) : "")
                            color: Theme.muted
                            font.pixelSize: 13; font.bold: true
                        }
                    }
                }
            }

            // clock
            Card {
                width: root.colWidth; height: 130
                fill: Theme.accent
                Column {
                    anchors.centerIn: parent
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.paper
                        font.pixelSize: 60; font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                        color: Theme.paper
                        font.pixelSize: 15; font.bold: true
                    }
                }
            }

            MediaPanel { width: root.colWidth; height: 150 }
        }

        Column {
            spacing: 20

            // system usage
            Card {
                width: root.colWidth
                height: stats.implicitHeight + 32 + offset
                Column {
                    id: stats
                    x: 16; y: 16
                    width: parent.width - 32
                    spacing: 12
                    Text {
                        text: "System"
                        color: Theme.ink
                        font.pixelSize: 18; font.bold: true
                    }
                    // Nerd Font: microchip f2db, memory efc5, hard-drive f0a0
                    StatBar { width: parent.width; label: "CPU"; glyph: 0xf2db; value: SysStats.cpu }
                    StatBar {
                        width: parent.width; label: "RAM"; glyph: 0xefc5; value: SysStats.mem
                        detail: SysStats.memUsedGb.toFixed(1) + " / " + SysStats.memTotalGb.toFixed(0) + " GB"
                    }
                    StatBar { width: parent.width; label: "Disk"; glyph: 0xf0a0; value: SysStats.disk }
                }
            }

            // calendar
            Card {
                width: root.colWidth
                height: cal.implicitHeight + 28 + offset
                MonthCalendar {
                    id: cal
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                }
            }
        }
    }
}
