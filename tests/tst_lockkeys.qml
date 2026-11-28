import QtQuick
import QtTest
import "../quickshell/services/LockKeysState.js" as State

TestCase {
    name: "LockKeysState"

    function test_two_keyboards() {
        const k = State.fromLeds("input3::capslock 1\ninput3::numlock 0\ninput9::capslock 0\n");
        compare(k.length, 2);
        compare(k[0].name, "input3");
        compare(k[0].capsLock, true);
        compare(k[0].numLock, false);
        compare(k[1].name, "input9");
        compare(k[1].capsLock, false);
    }

    function test_hyprland() {
        const k = State.fromHyprland('{"keyboards":[{"name":"a","capsLock":true,"numLock":false,"layout":"us"}]}');
        compare(k, [{ name: "a", capsLock: true, numLock: false }]);
    }

    // hyprctl prints [] or an error text at times: an empty list keeps the last snapshot
    function test_hyprland_not_json() {
        compare(State.fromHyprland("[]"), []);
        compare(State.fromHyprland("error: no instance"), []);
    }

    function test_missing_led() {
        const k = State.fromLeds("input9::capslock 1\n");
        compare(k[0].numLock, false);
    }
}
