import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services

// User avatar: the AccountsService icon (settings > Users), then ~/.face, else the initial on accent.
ClippingRectangle {
    id: root
    readonly property string user: Account.user
    // ?r= makes Image reload the file after a change
    readonly property var faces: [Account.avatar + "?r=" + Account.revision, Quickshell.env("HOME") + "/.face"]
    onFacesChanged: faceIndex = 0
    property int faceIndex: 0

    radius: Theme.radius
    color: Theme.accent
    border.width: Theme.border; border.color: Theme.line

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
        color: Theme.accentText
        font.pixelSize: root.height * 0.45; font.bold: true
    }
}
