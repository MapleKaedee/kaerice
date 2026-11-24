import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Temp note: a scratch text that is saved automatically (services/Note). Esc or the backdrop closes.
// Copy puts the whole note on the clipboard; Clear needs a second click within 2 s.
Overlay {
    id: root
    name: "note"
    color: Theme.scrimLight
    visible: Ui.note
    focusItem: edit
    onDismissed: { Note.flush(); Ui.note = false; }
    onVisibleChanged: {
        if (!visible) return;
        edit.text = Note.text;
        edit.cursorPosition = edit.length;
        clearArm.stop();
    }

    Timer { id: clearArm; interval: 2000 } // running = Clear was clicked once

    Card {
        anchors.centerIn: parent
        width: 680
        height: 500
        offset: 6

        MouseArea { anchors.fill: parent } // swallow clicks inside the card

        Column {
            x: 14; y: 14
            width: parent.width - 28
            spacing: 12

            Item {
                width: parent.width; height: 40
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Note"
                    color: Theme.ink
                    font.pixelSize: 20; font.bold: true
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    // Nerd Font: copy f0c5, trash f1f8
                    TextButton {
                        glyph: 0xf0c5; label: "Copy"
                        onClicked: if (edit.text) Quickshell.execDetached(["wl-copy", edit.text])
                    }
                    TextButton {
                        glyph: 0xf1f8; label: clearArm.running ? "Sure?" : "Clear"
                        hot: clearArm.running
                        onClicked: {
                            if (!clearArm.running) { clearArm.start(); return; }
                            clearArm.stop();
                            edit.text = "";
                            edit.forceActiveFocus();
                        }
                    }
                }
            }

            // writing area
            Card {
                width: parent.width
                height: 380
                offset: 3

                Flickable {
                    id: flick
                    anchors { fill: parent; margins: 14 }
                    contentHeight: edit.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // keep the cursor in view while typing
                    function follow(r) {
                        if (r.y < contentY) contentY = r.y;
                        else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
                    }

                    TextEdit {
                        id: edit
                        width: flick.width
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        color: Theme.ink
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.paper
                        font.pixelSize: 16
                        onTextChanged: Note.text = text
                        onCursorRectangleChanged: flick.follow(cursorRectangle)
                        Keys.onEscapePressed: root.dismissed()

                        Text {
                            visible: !edit.text
                            text: "Write anything. It stays until you clear it."
                            color: Theme.muted
                            font: edit.font
                        }
                    }
                }
            }

            Text {
                text: edit.length + " characters  ·  saved automatically  ·  Esc to close"
                color: Theme.muted
                font.pixelSize: 12; font.bold: true
            }
        }
    }
}
