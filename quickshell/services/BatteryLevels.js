.pragma library

// Which battery level to warn about. Pure, so tests/tst_battery.qml can check it.
// percent: 0..100. warned: lowest level already notified in this discharge (0 = none).
// Returns { warned, notify }: the new warned level, and the level to notify now (0 = nothing).
const levels = [3, 5, 10, 20]; // ascending
const rise = 5; // percent must climb this far above `warned` before it resets, so 10 <-> 11 does not repeat

function next(percent, onBattery, warned) {
    if (!onBattery) return { warned: 0, notify: 0 };
    const level = levels.find(l => percent <= l) ?? 0;
    if (level && (!warned || level < warned)) return { warned: level, notify: level };
    // charged while the shell was not running
    if (warned && percent > warned + rise) return { warned: level, notify: 0 };
    return { warned: warned, notify: 0 };
}
