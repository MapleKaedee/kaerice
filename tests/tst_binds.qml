import QtQuick
import QtTest
import "../quickshell/services/Binds.js" as Binds

TestCase {
    name: "Binds"

    function test_mango_description() {
        const r = Binds.mango("# Shell: launcher\nbind=SUPER,space,spawn,qs -c kaerice ipc call launcher toggle\n");
        compare(r.length, 1);
        compare(r[0].group, "Shell");
        compare(r[0].action, "launcher");
        compare(r[0].combo, ["SUPER", "Space"]);
    }

    function test_mango_flags_and_mods() {
        const r = Binds.mango("# Audio: volume up\nbindl=none,XF86AudioRaiseVolume,spawn,x\n\nbind=SUPER+SHIFT,q,killclient\n");
        compare(r[0].combo, ["Vol +"]);
        compare(r[1].group, "Other");
        compare(r[1].action, "killclient");
        compare(r[1].combo, ["SUPER", "SHIFT", "Q"]);
    }

    function test_mango_non_binds() {
        const r = Binds.mango("source=./conf/x.conf\n# Workspace: next\naxisbind=SUPER,DOWN,viewtoright_have_client\n"
            + "# dangling\n\nmousebind=SUPER,btn_left,moveresize,curmove\ngesturebind=none,left,3,viewtoright_have_client\n");
        compare(r.length, 3);
        compare(r[0].action, "next");
        compare(r[0].combo, ["SUPER", "Wheel ↓"]);
        compare(r[1].combo, ["SUPER", "LMB"]);
        compare(r[2].action, "viewtoright_have_client");
    }

    // the Alt release bind: Hyprland adds the key's own modifier
    function test_hyprland_unchanged() {
        const r = Binds.hyprland(JSON.stringify([{ modmask: 72, key: "Alt_L", description: "Shell: switch", dispatcher: "x" }]));
        compare(r[0].combo, ["SUPER", "Left Alt"]);
        compare(r[0].group, "Shell");
    }
}
