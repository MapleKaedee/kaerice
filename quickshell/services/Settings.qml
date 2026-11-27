pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "SettingsSchema.js" as Schema

// One file, linked to settings/ in the repo by install.sh. Parsed here, not with JsonAdapter:
// that shows defaults on the first frame and cannot reset.
Singleton {
    id: root
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/kaerice/settings.json"
    property var values: Schema.load(file.text()).values
    property var unknown: ({})
    readonly property bool changed: JSON.stringify(values) !== JSON.stringify(Schema.defaults())

    function get(key) {
        if (!(key in values)) console.warn("unknown setting", key);
        return values[key];
    }

    function set(key, value) {
        if (!Schema.schema[key]?.ok(value)) { console.warn("rejected setting", key, JSON.stringify(value)); return; }
        root.values = Object.assign({}, root.values, { [key]: value });
        save();
    }

    function reset() {
        backup();
        root.values = Schema.defaults();
        root.unknown = {};
        save();
    }

    function backup() { bak.setText(file.text()); }
    // at every change, not after a pause: a Singleton's onDestruction runs neither on a reload nor on exit
    function save() { file.setText(Schema.dump(root.values, root.unknown)); }

    // at start and after edits from outside
    function load() {
        const r = Schema.load(file.text());
        root.values = r.values;
        root.unknown = r.unknown;
        if (!r.problems.length) return;
        backup();
        Quickshell.execDetached(["notify-send", "-a", "kaerice", "Some settings were not usable",
            "Using defaults for: " + r.problems.join(", ") + ". The old file is in settings.json.bak."]);
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        blockWrites: true
        watchChanges: true
        printErrors: false
        onLoaded: root.load()
        onFileChanged: reload()
    }
    FileView { id: bak; path: root.path + ".bak"; blockWrites: true; printErrors: false; preload: false }
}
