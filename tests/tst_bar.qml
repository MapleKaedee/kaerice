import QtQuick
import QtTest
import "../quickshell/services/BarLayout.js" as Layout
import "../quickshell/services/SettingsSchema.js" as Schema

TestCase {
    name: "BarLayout"
    readonly property string def: Layout.defaults

    function test_default_has_every_card_once() {
        verify(Layout.valid(def));
        compare(Layout.hidden(def), []);
        compare(Layout.parse(def).left, ["workspaces", "title"]);
        compare(Layout.parse(def).center, ["media"]);
        compare(Layout.parse(def).right.length, 9);
    }

    function test_valid_data() {
        return [
            { tag: "all hidden", text: "||", ok: true },
            { tag: "extra spaces", text: "  clock |  | media  tray ", ok: true },
            { tag: "empty", text: "", ok: false },
            { tag: "two sections", text: "clock | media", ok: false },
            { tag: "four sections", text: "clock | media | tray |", ok: false },
            { tag: "unknown card", text: "clock | weather |", ok: false },
            { tag: "same card twice", text: "clock | clock |", ok: false },
            { tag: "name of an Object method", text: "constructor ||", ok: false },
            { tag: "number", text: 5, ok: false },
            { tag: "null", text: null, ok: false },
            { tag: "list", text: ["clock"], ok: false }
        ];
    }
    function test_valid(d) { compare(Layout.valid(d.text), d.ok); }

    function test_hidden() { compare(Layout.hidden("clock || media"), Layout.ids.filter(i => i !== "clock" && i !== "media")); }

    function test_move_data() {
        return [
            { tag: "later in its section", from: "workspaces title | media |", id: "workspaces", by: 1, to: "title workspaces | media |" },
            { tag: "into the next section", from: "workspaces title | media |", id: "title", by: 1, to: "workspaces | title media |" },
            { tag: "into the previous section", from: "workspaces | media |", id: "media", by: -1, to: "workspaces media ||" },
            { tag: "through an empty section", from: "clock | | media", id: "media", by: -1, to: "clock | media |" },
            { tag: "first stays first", from: "clock | media |", id: "clock", by: -1, to: "clock | media |" },
            { tag: "last stays last", from: "clock || media", id: "media", by: 1, to: "clock || media" },
            { tag: "a hidden card does not move", from: "clock || media", id: "tray", by: 1, to: "clock || media" }
        ];
    }
    function test_move(d) {
        const r = Layout.move(d.from, d.id, d.by);
        compare(Layout.parse(r), Layout.parse(d.to));
        verify(Layout.valid(r));
    }

    function test_canMove() {
        verify(!Layout.canMove("clock | media |", "clock", -1));
        verify(Layout.canMove("clock | media |", "clock", 1));
        verify(!Layout.canMove("clock || media", "tray", 1));
    }

    function test_toggle_hides_and_shows() {
        const off = Layout.toggle(def, "tray");
        compare(Layout.hidden(off), ["tray"]);
        const on = Layout.toggle(off, "tray");
        compare(Layout.hidden(on), []);
        compare(Layout.section(on, "tray"), "right", "back in its default section");
        compare(Layout.section(Layout.toggle(Layout.toggle(def, "media"), "media"), "media"), "center");
    }

    function test_section() {
        compare(Layout.section(def, "clock"), "right");
        compare(Layout.section(def, "title"), "left");
        compare(Layout.section("||", "clock"), "");
    }

    function test_settings() {
        compare(Schema.load('{"bar.cards": "clock || media"}').values["bar.cards"], "clock || media");
        compare(Schema.load('{"bar.cards": "clock"}').problems, ["bar.cards"]);
        compare(Schema.load('{"bar.size": 10}').problems, ["bar.size"]);
        compare(Schema.load('{"bar.position": "left"}').problems, ["bar.position"]);
        compare(Schema.load('{"bar.monitor": "DP-1"}').values["bar.monitor"], "DP-1");
        compare(Schema.load('{"bar.monitor": ""}').problems, ["bar.monitor"]);
        compare(Schema.load('{"bar.monitor": "a b"}').problems, ["bar.monitor"]);
    }

    function test_screens() {
        const a = { name: "eDP-1" }, b = { name: "DP-1" };
        compare(Layout.screens([a, b], "all"), [a, b]);
        compare(Layout.screens([a, b], "DP-1"), [b]);
        compare(Layout.screens([a], "DP-1"), [a], "the chosen monitor is gone: every monitor, never none");
    }
}
