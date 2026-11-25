.pragma library

// payload: the "network" topic of kaericed; undefined before the first one
function view(payload, down) {
    if (down) return { kind: "unavailable", label: "N/A" };
    switch (payload?.kind) {
    case "eth": return { kind: "eth", label: "ETH" };
    case "wifi": return { kind: "wifi", label: (payload.ssid || "WIFI").slice(0, 14) };
    case "offline": return { kind: "offline", label: "OFFLINE" };
    default: return { kind: "wifi", label: "NET" };
    }
}
