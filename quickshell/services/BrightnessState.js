.pragma library

// payload: the "brightness" topic of kaericed; undefined before the first one, while it is down, and without a backlight
function level(payload) {
    const p = payload?.percent;
    return Number.isInteger(p) && p >= 0 && p <= 100 ? p : -1;
}

// never below 1% so the screen can't go black
function clamp(p) {
    return Math.max(1, Math.min(100, Math.round(p)));
}
