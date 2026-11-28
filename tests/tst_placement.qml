import QtQuick
import QtTest
import "../quickshell/services/Placement.js" as Placement

TestCase {
    name: "Placement"

    function test_same_app_and_title() {
        const p = Placement.match(
            [{ appId: "kitty", title: "fish" }, { appId: "kitty", title: "fish" }],
            [{ id: 4, appid: "kitty", title: "fish", tags: [1], x: 0 }, { id: 7, appid: "kitty", title: "fish", tags: [3], x: 0 }]);
        compare(p[0].workspace, "1");
        compare(p[1].workspace, "3");
        compare(p[1].order, 3);
        compare(p[1].id, 7); // Mango ignores the protocol's activate: the switcher focuses by this id

    }

    // the title changes between the list and the mmsg answer (a terminal running a command)
    function test_title_changed() {
        const p = Placement.match(
            [{ appId: "firefox", title: "Docs" }, { appId: "kitty", title: "vim" }],
            [{ appid: "kitty", title: "fish", tags: [2], x: 40 }, { appid: "firefox", title: "Docs", tags: [1], x: 0 }]);
        compare(p[0].workspace, "1");
        compare(p[1].workspace, "2");
        compare(p[1].x, 40);
    }

    function test_unknown_window() {
        const p = Placement.match([{ appId: "foot", title: "" }], [{ appid: "kitty", title: "fish", tags: [1], x: 0 }]);
        compare(p[0], null);
    }
}
