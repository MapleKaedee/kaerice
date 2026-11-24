import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.config

// User avatar: ~/.face, then the AccountsService icon, else the initial on accent.
ClippingRectangle {
    id: root
    readonly property string user: Quickshell.env("USER")
    readonly property var faces: [Quickshell.env("HOME") + "/.face", "/var/lib/AccountsService/icons/" + user]
    property int faceIndex: 0

    radius: Theme.radius
    color: Theme.accent
    border.width: Theme.border; border.color: Theme.ink

    Image {
        id: face
        anchors.fill: parent
        source: root.faceIndex < root.faces.length ? "file://" + root.faces[root.faceIndex] : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        onStatusChanged: if (status === Image.Error) root.faceIndex++
    }
    Text {
        anchors.centerIn: parent
        visible: face.status !== Image.Ready
        text: root.user.charAt(0).toUpperCase()
        color: Theme.paper
        font.pixelSize: root.height * 0.45; font.bold: true
    }
}
