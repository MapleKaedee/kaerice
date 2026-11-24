import Quickshell
import QtQuick
import qs.config
import qs.components.base

// HH:mm clock on an accent card.
TextCard {
    text: Qt.formatDateTime(clock.date, "HH:mm")
    icon: String.fromCodePoint(0xf017) // Nerd Font clock
    fill: Theme.accent
    textColor: Theme.paper

    SystemClock { id: clock; precision: SystemClock.Minutes }
}
