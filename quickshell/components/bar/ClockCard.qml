import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Date + HH:mm clock on an accent card. Click opens the calendar.
TextCard {
    text: Qt.formatDateTime(clock.date, "d MMM yyyy  ·  HH:mm")
    icon: String.fromCodePoint(0xf017) // Nerd Font clock
    fill: Theme.accent
    textColor: Theme.paper

    SystemClock { id: clock; precision: SystemClock.Minutes }
    MouseArea { anchors.fill: parent; onClicked: Ui.calendar = !Ui.calendar }
}
