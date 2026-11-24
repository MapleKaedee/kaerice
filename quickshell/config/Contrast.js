.pragma library

// WCAG contrast between QML colors. Pure, so tests/tst_contrast.qml can check it.
function luminance(c) {
    const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

// 1 (same) .. 21 (black on white)
function ratio(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// first while it reads on bg (3:1, enough for bold text and icons), else second
function pick(bg, first, second) { return ratio(bg, first) >= 3 ? first : second; }
