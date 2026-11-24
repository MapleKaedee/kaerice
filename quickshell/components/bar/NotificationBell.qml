import QtQuick
import qs.services
import qs.components.base

// Notification count + bell (bell-slash while do-not-disturb). Click opens the history panel.
TextCard {
    icon: String.fromCodePoint(Notifs.dnd ? 0xf1f6 : 0xf0f3)
    text: "" + Notifs.count

    MouseArea { anchors.fill: parent; onClicked: Ui.notifications = !Ui.notifications }
}
