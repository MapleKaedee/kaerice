import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Wi-Fi menu (iwd): networks by signal, rescan, power, connect, password for new WPA networks, disconnect.
Overlay {
    id: root
    property string expanded: "" // path of the network showing the password field

    function pick(n) {
        if (n.connected || Wifi.busy) return;
        if (n.known || n.type === "open") { root.expanded = ""; Wifi.connect(n, ""); }
        else if (n.type === "psk") root.expanded = root.expanded === n.path ? "" : n.path;
        else Wifi.status = "Enterprise (802.1X) network: set it up once with iwctl";
    }

    // 4-step signal level from dBm
    function bars(dbm) { return dbm >= -55 ? 4 : dbm >= -67 ? 3 : dbm >= -75 ? 2 : 1; }

    name: "wifi"
    visible: Ui.wifi
    onDismissed: Ui.wifi = false
    onVisibleChanged: {
        root.expanded = "";
        if (!visible) return;
        Wifi.status = "";
        Wifi.scan();
    }

    Card {
        x: BarLayout.panelX("network", width, parent.width)
        y: BarLayout.panelY(height, parent.height)
        width: 380
        height: col.implicitHeight + 24 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the menu

        Column {
            id: col
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10

            // header: title, rescan, power
            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi" + (Wifi.device ? "  ·  " + Wifi.device : "")
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    Card {
                        visible: Wifi.powered
                        width: 38; height: 36; offset: Theme.depth(3)
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xf021) // refresh
                            color: Theme.text
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        MouseArea { anchors.fill: parent; onClicked: Wifi.scan() }
                    }
                    Card {
                        visible: Wifi.device !== ""
                        width: 38; height: 36; offset: Theme.depth(3)
                        fill: Wifi.powered ? Theme.accent : Theme.face
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xf011) // power
                            color: Wifi.powered ? Theme.accentText : Theme.text
                            font.family: Theme.iconFont; font.pixelSize: 16
                        }
                        MouseArea { anchors.fill: parent; onClicked: Wifi.togglePower() }
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: Wifi.note
                color: Theme.text
                opacity: 0.75
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, 7 * 48)
                visible: count > 0
                clip: true
                spacing: 6
                // paths only: a row keeps its password field when the networks change
                model: ScriptModel { values: Wifi.networks.map(n => n.path) }
                currentIndex: -1   // a current row takes the focus from that field when rows move

                delegate: Column {
                    id: row
                    required property string modelData
                    readonly property var net: Wifi.networks.find(n => n.path === modelData)
                        ?? ({ path: modelData, name: "", type: "open", connected: false, dbm: -100 })
                    readonly property bool isOpen: root.expanded === modelData
                    readonly property color fg: net.connected ? Theme.accentText : Theme.text
                    width: list.width
                    spacing: 6

                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: Theme.corner(6)
                        color: row.net.connected ? Theme.accent : hover.containsMouse ? Theme.hover : "transparent"
                        border.width: row.net.connected || row.isOpen ? Theme.border : 0
                        border.color: Theme.line

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.pick(row.net)
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 10

                            // signal: filled bars + faded rest
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: "▂▄▆█".slice(0, root.bars(row.net.dbm))
                                    color: row.fg
                                    font.family: Theme.iconFont; font.pixelSize: 14
                                }
                                Text {
                                    text: "▂▄▆█".slice(root.bars(row.net.dbm))
                                    color: row.fg
                                    opacity: 0.25
                                    font.family: Theme.iconFont; font.pixelSize: 14
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 230
                                text: row.net.name
                                elide: Text.ElideRight
                                color: row.fg
                                font.pixelSize: 14; font.bold: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.net.type !== "open"
                                text: String.fromCodePoint(0xf023) // lock
                                color: row.fg
                                font.family: Theme.iconFont; font.pixelSize: 13
                            }
                        }

                        // disconnect button on the connected network
                        Text {
                            visible: row.net.connected
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: String.fromCodePoint(0xf00d) // x
                            color: row.fg
                            font.family: Theme.iconFont; font.pixelSize: 16
                            MouseArea {
                                anchors { fill: parent; margins: -8 }
                                onClicked: Wifi.disconnect()
                            }
                        }
                    }

                    // password field for a new secured network
                    Card {
                        visible: row.isOpen
                        width: parent.width
                        height: 44
                        offset: Theme.depth(3)

                        TextInput {
                            id: pass
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.pixelSize: 14
                            onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                            Keys.onReturnPressed: join()
                            Keys.onEnterPressed: join()
                            Keys.onEscapePressed: { root.expanded = ""; root.focusItem.forceActiveFocus(); }

                            function join() {
                                if (!text) return;
                                const secret = text;   // closing the field empties it
                                root.expanded = "";
                                root.focusItem.forceActiveFocus();
                                Wifi.connect(row.net, secret);
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !pass.text
                                text: "Password, then Enter"
                                color: Theme.muted
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}
