.pragma library

// payload: the "sleep" topic of kaericed; undefined from an older one, null while it cannot hold a suspend or is gone
function guarded(payload) {
    return typeof payload?.preparing === "boolean";
}

function preparing(payload) {
    return payload?.preparing === true;
}
