pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Caps Lock / Num Lock popups. Hyprland keeps one lock state per keyboard (power buttons included), so a key
// press is resolved by finding the keyboard whose state changed since the last read. No change (key remapped) = no popup.
Singleton {
    id: root
    property bool on: false      // state of the key shown in the OSD
    property var last: ({})      // keyboard name -> { capsLock, numLock } at the last read
    property var pending: []     // keys released since then: "capsLock" | "numLock"

    // called by the key binds on release; the delay lets Hyprland settle the new state
    function released(key) {
        root.pending = root.pending.concat([key]);
        delay.restart();
    }

    function parse(json) {
        let keyboards;
        try { keyboards = JSON.parse(json).keyboards; } catch (e) {} // hyprctl prints [] or an error text at times
        // keep the old snapshot: an empty one makes the next press show the first keyboard's state (a power button)
        if (!Array.isArray(keyboards)) { root.pending = []; return; }
        for (const key of root.pending) {
            // else a keyboard plugged in after the last read
            const source = keyboards.find(k => root.last[k.name] && root.last[k.name][key] !== k[key])
                ?? keyboards.find(k => !root.last[k.name]);
            if (!source) continue;
            root.on = source[key];
            Osd.show(key);
        }
        root.pending = [];
        const now = {};
        for (const k of keyboards) now[k.name] = { capsLock: k.capsLock, numLock: k.numLock };
        root.last = now;
    }

    Timer { id: delay; interval: 40; onTriggered: if (reader.running) restart(); else reader.running = true }

    // also runs once at startup for the first snapshot
    Process {
        id: reader
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { id: out; onStreamFinished: root.parse(out.text) }
    }
}
