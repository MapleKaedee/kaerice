import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Avatar and real name (AccountsService), and a way to change the password (passwd in a terminal).
Item {
    id: root
    implicitHeight: col.implicitHeight

    // The picked avatar, cropped to a square and scaled down: AccountsService refuses files over 1 MB.
    // Clipped away here; grabToImage still renders it.
    Item {
        clip: true
        Image {
            width: 512; height: 512
            source: Account.picked ? "file://" + Account.picked.split("/").map(encodeURIComponent).join("/") : ""
            asynchronous: true
            cache: false
            autoTransform: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(512, 512)
            onStatusChanged: {
                if (status === Image.Error) { Account.error = "That file is not a usable image."; Account.picked = ""; }
                if (status !== Image.Ready) return;
                grabToImage(result => {
                    const file = Quickshell.env("XDG_RUNTIME_DIR") + "/kaerice-avatar.jpg";
                    if (result.saveToFile(file)) Account.setAvatar(file);
                    else Account.error = "The avatar could not be saved.";
                    Account.picked = "";
                });
            }
        }
    }

    component Label: Text {
        color: Theme.ink
        font.pixelSize: 15; font.bold: true
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Row {
            spacing: 18
            Avatar { width: 96; height: 96 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: Account.name
                    color: Theme.ink
                    font.pixelSize: 20; font.bold: true
                }
                Text {
                    text: Account.user + "@" + SysStats.host
                    color: Theme.muted
                    font.pixelSize: 13; font.bold: true
                }
                TextButton { glyph: 0xf03e; label: "Change avatar"; onClicked: Account.pickAvatar() } // image
            }
        }

        Item { width: 1; height: 4 }
        Label { text: "Name" }
        Row {
            spacing: 12
            Card {
                width: 320; height: 38; offset: 3
                TextInput {
                    id: name
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    maximumLength: 64
                    activeFocusOnTab: true
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.paper
                    color: Theme.ink
                    font.pixelSize: 15; font.bold: true
                    Component.onCompleted: text = Account.realName
                    onAccepted: Account.setName(text)
                    Connections {
                        target: Account
                        function onRealNameChanged() { name.text = Account.realName; }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !name.text
                        text: Account.user
                        color: Theme.muted
                        font: name.font
                    }
                }
            }
            TextButton { // floppy
                glyph: 0xf0c7; label: "Save"
                enabled: name.text.trim() !== Account.realName
                onClicked: Account.setName(name.text)
            }
        }

        Item { width: 1; height: 4 }
        Label { text: "Password" }
        TextButton { glyph: 0xf084; label: "Change password"; onClicked: Account.changePassword() } // key
        Text {
            text: "Opens passwd in a terminal. Kaerice never sees the password."
            color: Theme.muted
            font.pixelSize: 12; font.bold: true
        }

        Card {
            visible: Account.error !== ""
            width: parent.width; height: err.implicitHeight + 20 + offset
            offset: 3
            fill: Theme.accent
            Text {
                id: err
                x: 12; y: 10
                width: parent.width - 24
                wrapMode: Text.Wrap
                text: Account.error
                color: Theme.paper
                font.pixelSize: 13; font.bold: true
            }
        }
    }
}
