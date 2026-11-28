pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Binds.js" as Binds
import "CompositorState.js" as State
import "LockKeysState.js" as LockKeysState
import "Placement.js" as Placement

// What the Wayland protocols leave out, one branch per compositor (Hyprland, Mango).
Singleton {
    id: root
    readonly property string name: State.detect({
        desktop: Quickshell.env("XDG_CURRENT_DESKTOP") || "",
        mango: Quickshell.env("MANGO_INSTANCE_SIGNATURE") || "",
        hyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    })
    readonly property bool hyprland: name === "hyprland"
    readonly property bool mango: name === "mango"
    readonly property string label: hyprland ? "Hyprland" : mango ? "Mango" : ""

    // Quickshell 0.3.2 captures a window only through hyprland_toplevel_export; elsewhere the switcher shows app icons
    readonly property bool windowPreviews: hyprland

    // Hyprland keeps the last window active on an empty workspace, Mango clears it
    readonly property bool emptyWorkspace: hyprland && !Hyprland.focusedWorkspace?.toplevels.values.length

    readonly property string versionCommand: hyprland ? "hyprctl version -j | jq -r .version"
        : mango ? "mmsg get version | jq -r .version" : ""

    // $1 theme, $2 size. Mango reads the cursor theme "default", the link kaericed points at the copy, at a reload.
    readonly property string cursorCommand: hyprland ? `hyprctl setcursor "$1" "$2"`
        : mango ? "mmsg dispatch reload_config" : ""

    readonly property var bindsCommand: hyprland ? ["hyprctl", "binds", "-j"]
        : mango ? ["sh", "-c", 'cat "${XDG_CONFIG_HOME:-$HOME/.config}"/mango/conf/binds*.conf'] : ["true"]
    readonly property string bindsSource: hyprland ? "hypr/conf/binds*.lua" : mango ? "mango/conf/binds*.conf" : ""
    function parseBinds(text) { return hyprland ? Binds.hyprland(text) : mango ? Binds.mango(text) : []; }

    // Hyprland keeps a lock state per keyboard but lights every keyboard's LED from the last one that changed: ask it.
    // Mango shares one state across keyboards, so the LEDs are right.
    readonly property var lockKeysCommand: hyprland ? ["hyprctl", "devices", "-j"]
        : ["sh", "-c", `for f in /sys/class/leds/*::capslock /sys/class/leds/*::numlock; do
            [ -e "$f" ] && echo "\${f##*/} $(cat "$f/brightness")"; done`]
    function parseLockKeys(text) { return hyprland ? LockKeysState.fromHyprland(text) : LockKeysState.fromLeds(text); }

    function dpms(on) {
        if (hyprland) Hyprland.dispatch(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`);
        else if (mango) Quickshell.execDetached(["mmsg", "dispatch", on ? "wakeup_monitor" : "sleep_monitor"]);
    }

    // Workspace and position of each window, for the switcher and overview: asked for when they open.
    function refreshPlacement() {
        if (hyprland) Hyprland.refreshToplevels(); // lastIpcObject (the position) is only fresh after this
        else if (mango) clients.running = true;
    }

    // -> { workspace, order, x, id (Mango) } | null. Read in a binding: it changes when the answer arrives.
    function place(t) {
        if (hyprland) {
            const h = Hyprland.toplevels.values.find(h => h.wayland === t);
            return h ? { workspace: h.workspace?.name ?? "", order: h.workspace?.id ?? 0, x: h.lastIpcObject.at?.[0] ?? 0 } : null;
        }
        if (!mango || !mangoClients.length) return null;
        const all = ToplevelManager.toplevels.values;
        return Placement.match(all.map(w => ({ appId: w.appId, title: w.title })), mangoClients)[all.indexOf(t)] ?? null;
    }

    // Mango ignores the protocol's activate (tested headless, also with focus_on_activate=1): focus by client id,
    // which also shows the window's tag
    function activate(t) {
        const id = mango ? place(t)?.id : undefined;
        if (id !== undefined) Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + id]);
        else t.activate();
    }

    property var mangoClients: []

    Process {
        id: clients
        command: ["mmsg", "get", "all-clients"]
        stdout: StdioCollector {
            id: clientsOut
            onStreamFinished: { try { root.mangoClients = JSON.parse(clientsOut.text).clients; } catch (e) {} }
        }
    }
}
