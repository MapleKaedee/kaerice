import Quickshell.Services.UPower
import QtQuick

// Laptop battery. "+" while on AC, red when <= 20% on battery.
TextCard {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property int percent: Math.round(dev.percentage * 100)
    readonly property bool low: UPower.onBattery && percent <= 20

    visible: dev.isLaptopBattery
    text: "BAT " + percent + "%" + (UPower.onBattery ? "" : "+")
    fill: low ? "#e8335a" : "#f2f0eb"
    textColor: low ? "#f2f0eb" : "#1c1c1c"
}
