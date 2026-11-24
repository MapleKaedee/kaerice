import Quickshell.Services.UPower
import QtQuick
import qs.config
import qs.components.base

// Laptop battery. Bolt icon while on AC, red when <= 20% on battery.
TextCard {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property int percent: Math.round(dev.percentage * 100)
    readonly property bool low: UPower.onBattery && percent <= 20

    visible: dev.isLaptopBattery
    text: percent + "%"
    // Nerd Font glyphs: bolt on AC, otherwise battery full/three-quarters/half/quarter/empty
    icon: String.fromCodePoint(!UPower.onBattery ? 0xf0e7
        : percent >= 88 ? 0xf240 : percent >= 63 ? 0xf241 : percent >= 38 ? 0xf242 : percent >= 13 ? 0xf243 : 0xf244)
    fill: low ? Theme.accent : Theme.face
    textColor: low ? Theme.accentText : Theme.text
}
