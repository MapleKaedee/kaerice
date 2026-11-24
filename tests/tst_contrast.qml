import QtQuick
import QtTest
import "../quickshell/config/Contrast.js" as Contrast

TestCase {
    name: "Contrast"
    readonly property color ink: "#1c1c1c"
    readonly property color paper: "#f2f0eb"

    function test_ratio() {
        compare(Math.round(Contrast.ratio(Qt.rgba(0, 0, 0, 1), Qt.rgba(1, 1, 1, 1))), 21);
        compare(Contrast.ratio(paper, paper), 1);
        compare(Contrast.ratio(ink, paper), Contrast.ratio(paper, ink));
    }

    function test_pick_data() {
        return [
            { tag: "default accent keeps light text", bg: "#e8335a", light: true },
            { tag: "yellow", bg: "#f5b82e", light: false },
            { tag: "white", bg: "#ffffff", light: false },
            { tag: "black", bg: "#000000", light: true }
        ];
    }
    function test_pick(d) {
        const bg = Qt.color(d.bg);
        compare(Contrast.pick(bg, paper, ink), d.light ? paper : ink);
    }

    // whatever accent is typed in, the text on it stays readable
    function test_every_accent_is_readable() {
        for (let r = 0; r <= 255; r += 15) for (let g = 0; g <= 255; g += 15) for (let b = 0; b <= 255; b += 15) {
            const bg = Qt.rgba(r / 255, g / 255, b / 255, 1);
            verify(Contrast.ratio(bg, Contrast.pick(bg, paper, ink)) >= 3, String(bg));
        }
    }
}
