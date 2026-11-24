import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Month calendar under the clock (top-right). Arrows / scroll / Left-Right change month,
// click the month title to jump back to today. Week start and names follow the system locale.
Overlay {
    id: root
    name: "calendar"
    visible: Ui.calendar
    onDismissed: Ui.calendar = false
    onVisibleChanged: if (visible) reset()

    readonly property var locale: Qt.locale()
    readonly property date today: clock.date
    property date shown: new Date(today.getFullYear(), today.getMonth(), 1)
    // first cell: the week-start day on or before the 1st (getDay and firstDayOfWeek both use 0 = Sunday)
    readonly property date gridStart: {
        const lead = (shown.getDay() - locale.firstDayOfWeek + 7) % 7;
        return new Date(shown.getFullYear(), shown.getMonth(), 1 - lead);
    }

    function move(months) { shown = new Date(shown.getFullYear(), shown.getMonth() + months, 1); }
    function reset() { shown = new Date(today.getFullYear(), today.getMonth(), 1); }

    SystemClock { id: clock; precision: SystemClock.Hours }

    Card {
        x: parent.width - width - 14
        y: 60
        width: col.implicitWidth + 24 + offset
        height: col.implicitHeight + 24 + offset
        offset: 6

        MouseArea { // swallow clicks inside the panel; scroll changes month
            anchors.fill: parent
            onWheel: wheel => root.move(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        Column {
            id: col
            x: 12; y: 12
            spacing: 10

            // header: prev, "Month Year", next
            Item {
                width: grid.width
                height: 36

                component Arrow: Card {
                    id: arrow
                    property int glyph
                    signal clicked()
                    width: 38; height: 36; offset: 3
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(arrow.glyph)
                        color: Theme.ink
                        font.family: Theme.iconFont; font.pixelSize: 16
                    }
                    MouseArea { anchors.fill: parent; onClicked: arrow.clicked() }
                }

                Arrow { glyph: 0xf053; onClicked: root.move(-1) } // chevron-left
                Text {
                    anchors.centerIn: parent
                    text: root.locale.standaloneMonthName(root.shown.getMonth()) + " " + root.shown.getFullYear()
                    color: Theme.ink
                    font.pixelSize: 18; font.bold: true
                    MouseArea { anchors.fill: parent; onClicked: root.reset() }
                }
                Arrow { anchors.right: parent.right; glyph: 0xf054; onClicked: root.move(1) } // chevron-right
            }

            Grid {
                id: grid
                columns: 7
                spacing: 4

                // weekday names, starting at the locale's first day
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: 40; height: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: root.locale.dayName((root.locale.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                        color: Theme.muted
                        font.pixelSize: 12; font.bold: true
                    }
                }

                // 6 weeks of days
                Repeater {
                    model: 42
                    Rectangle {
                        required property int index
                        readonly property date day: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                        readonly property bool inMonth: day.getMonth() === root.shown.getMonth()
                        readonly property bool isToday: day.toDateString() === root.today.toDateString()
                        width: 40; height: 36
                        radius: Theme.radius
                        color: isToday ? Theme.accent : "transparent"
                        border.width: isToday ? Theme.border : 0
                        border.color: Theme.ink
                        Text {
                            anchors.centerIn: parent
                            text: parent.day.getDate()
                            color: parent.isToday ? Theme.paper : parent.inMonth ? Theme.ink : Theme.muted
                            font.pixelSize: 14; font.bold: parent.inMonth
                        }
                    }
                }
            }
        }
    }

    Item {
        id: calKeys
        focus: true
        Keys.onEscapePressed: root.dismissed()
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
    }
    focusItem: calKeys
}
