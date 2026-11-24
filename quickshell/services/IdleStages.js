.pragma library

// Idle stages in the order they must happen. Times are seconds since the last input, 0 = never.
const keys = ["idle.dim", "idle.lock", "idle.screenOff", "idle.suspend"];
const choices = [30, 60, 90, 120, 150, 180, 240, 300, 330, 360, 420, 480, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200];

// times (same order as keys) -> the choices for stage i that keep the order; stages set to never do not count
function allowed(times, i) {
    return choices.filter(c => times.every((t, j) => !t || (j < i ? t < c : j > i ? t > c : true)));
}

function text(seconds) {
    if (!isFinite(seconds) || seconds === 0) return "Never";
    if (seconds < 60) return seconds + " s";
    if (seconds < 3600) return Math.round(seconds / 6) / 10 + " min";
    return Math.round(seconds / 360) / 10 + " h";
}
