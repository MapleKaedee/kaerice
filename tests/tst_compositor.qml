import QtQuick
import QtTest
import "../quickshell/services/CompositorState.js" as State

TestCase {
    name: "CompositorState"

    // the systemd environment keeps the signature of a Hyprland session that already ended
    function test_stale_hyprland_in_mango() {
        compare(State.detect({ desktop: "mango:wlroots", mango: "", hyprland: "abc" }), "mango");
    }

    function test_stale_mango_in_hyprland() {
        compare(State.detect({ desktop: "Hyprland", mango: "/run/user/1000/mango-1.sock", hyprland: "abc" }), "hyprland");
    }

    function test_signature_only() {
        compare(State.detect({ desktop: "", mango: "", hyprland: "abc" }), "hyprland");
        compare(State.detect({ desktop: "", mango: "", hyprland: "" }), "");
    }
}
