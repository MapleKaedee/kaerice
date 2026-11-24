import QtQuick
import qs.config
import qs.services
import qs.components.base

// Month calendar at the bar, on the side of the clock. Arrows / scroll / Left-Right change month,
// click the month title to jump back to today.
Overlay {
    id: root
    name: "calendar"
    visible: Ui.calendar
    onDismissed: Ui.calendar = false
    onVisibleChanged: if (visible) cal.reset()

    Card {
        x: BarLayout.panelX("clock", width, parent.width)
        y: BarLayout.panelY(height, parent.height)
        width: cal.implicitWidth + 24 + offset
        height: cal.implicitHeight + 24 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the panel

        MonthCalendar { id: cal; x: 12; y: 12 }
    }

    Item {
        id: calKeys
        focus: true
        Keys.onEscapePressed: root.dismissed()
        Keys.onLeftPressed: cal.move(-1)
        Keys.onRightPressed: cal.move(1)
    }
    focusItem: calKeys
}
