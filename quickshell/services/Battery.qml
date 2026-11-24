pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "BatteryLevels.js" as Levels

// Battery notifications: warnings at 20 / 10 / 5 / 3 % while discharging (5 and 3 stay until clicked, even in
// do-not-disturb), and charger connected / disconnected. Warnings only: nothing suspends or powers off.
// The level already warned about is a state file, so a reload or restart does not repeat it.
Singleton {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property bool available: device.ready && device.isLaptopBattery
    readonly property int percent: Math.round(device.percentage * 100)
    readonly property bool unplugged: UPower.onBattery
    property bool armed: false
    property int warned: parseInt(saved.text()) || 0

    onWarnedChanged: saved.setText(String(warned))
    onPercentChanged: check()
    onUnpluggedChanged: {
        if (armed && available)
            notify("normal", unplugged ? "Charger disconnected" : "Charger connected", "Battery at " + percent + "%");
        check();
    }

    function check() {
        if (!armed || !available) return;
        const r = Levels.next(percent, unplugged, warned);
        root.warned = r.warned;
        if (r.notify)
            notify(r.notify <= 5 ? "critical" : "normal", "Battery at " + percent + "%",
                   r.notify <= 5 ? "Plug in now and save your work." : "Plug in the charger soon.");
    }

    function notify(urgency, title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, title, body]);
    }

    // UPower values arrive one by one after start; without the wait that looks like the charger being unplugged
    Timer { interval: 3000; running: true; onTriggered: { root.armed = true; root.check(); } }

    FileView { id: saved; path: Quickshell.statePath("battery-warned"); blockLoading: true; printErrors: false }
}
