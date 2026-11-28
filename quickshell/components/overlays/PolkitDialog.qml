import QtQuick
import qs.config
import qs.services
import qs.components.base

// Polkit password dialog. Enter or OK answers, Esc, Cancel or a click outside the card cancels.
// After a wrong password polkit starts a new attempt by itself: the field takes input again.
Overlay {
    id: root
    readonly property var flow: Polkit.agent.flow
    readonly property bool waiting: !(flow?.isResponseRequired ?? false)

    function answer() {
        if (waiting) return;
        flow.submit(input.text);
        input.text = "";
    }

    name: "polkit"
    color: Theme.scrim
    visible: Polkit.agent.isActive
    focusItem: input
    onDismissed: flow?.cancelAuthenticationRequest()

    Card {
        anchors.centerIn: parent
        width: 440 + offset
        height: content.implicitHeight + 40 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 14

            Row {
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xf084) // Nerd Font key
                    color: Theme.text
                    font.family: Theme.iconFont; font.pixelSize: 20
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Authentication required"
                    color: Theme.text
                    font.pixelSize: 18; font.bold: true
                }
            }

            Text {
                width: parent.width
                text: root.flow?.message ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.text
                font.pixelSize: 14
            }

            Text {
                width: parent.width
                text: root.flow?.selectedIdentity?.displayName || root.flow?.selectedIdentity?.string || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.muted
                font.pixelSize: 13; font.bold: true
            }

            Card {
                width: parent.width; height: 48
                offset: Theme.depth(3)
                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    // readOnly, not enabled: a disabled field drops the focus, and Esc with it
                    readOnly: root.waiting
                    clip: true
                    color: Theme.text
                    font.pixelSize: 16; font.bold: true
                    onAccepted: root.answer()
                    Keys.onEscapePressed: root.dismissed()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.waiting ? "Checking..." : (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font: input.font
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.flow?.supplementaryMessage || (root.flow?.failed ? "Wrong password, try again" : "")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: root.flow?.supplementaryIsError || root.flow?.failed ? Theme.highlight : Theme.muted
                font.pixelSize: 13; font.bold: true
            }

            Row {
                anchors.right: parent.right
                spacing: 10
                // Nerd Font: xmark f00d, check f00c
                TextButton { glyph: 0xf00d; label: "Cancel"; onClicked: root.dismissed() }
                TextButton { glyph: 0xf00c; label: "OK"; hot: true; enabled: !root.waiting; onClicked: root.answer() }
            }
        }
    }
}
