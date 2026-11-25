.pragma library

const DOWN = "Unavailable: kaericed is not running";

// payload: the "wifi" topic of kaericed; undefined before the first one and from an older daemon
function view(payload, down) {
    const known = !down && payload !== null && typeof payload === "object";
    const on = known && !!payload.device;
    return {
        device: on ? payload.device : "",
        powered: on && !!payload.powered,
        networks: on && Array.isArray(payload.networks) ? payload.networks : [],
        note: down ? DOWN
            : !known ? "Waiting for kaericed. If this stays, run ./install.sh"
            : !on ? "No Wi-Fi device found"
            : !payload.powered ? "Wi-Fi is off"
            : payload.scanning ? "Scanning…" : ""
    };
}

// code: from kaericed, "" when the call succeeded
function errorText(code, withPassword) {
    switch (code) {
    case "": return "";
    case "Failed": return withPassword ? "Could not connect. Is the password right?" : "Failed";
    case "InvalidFormat": return "The password must have 8 to 63 characters";
    case "Busy":
    case "InProgress": return "Still connecting to another network";
    case "Timeout": return "iwd did not answer";
    case "Unavailable": return "iwd is not running";
    case "Disconnected": return DOWN;
    case "UnknownCall": return "Run ./install.sh to update kaericed";
    default: return "Failed: " + code;
    }
}
