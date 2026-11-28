.pragma library

// Mango: toplevels ([{ appId, title }], from ToplevelManager) paired with `mmsg get all-clients` clients, which carry the
// tag and position the Wayland protocol lacks. Neither has an id of the other, so: same app and title first, then same
// app, each client used once, both in creation order. -> [{ workspace, order, x, id } | null], one per toplevel.
function match(toplevels, clients) {
    const used = clients.map(() => false);
    const out = toplevels.map(() => null);
    const pass = same => toplevels.forEach((t, i) => {
        if (out[i]) return;
        const j = clients.findIndex((c, k) => !used[k] && c.appid === t.appId && (!same || c.title === t.title));
        if (j < 0) return;
        used[j] = true;
        const tag = clients[j].tags[0] ?? 0;
        out[i] = { workspace: String(tag), order: tag, x: clients[j].x, id: clients[j].id };
    });
    pass(true);
    pass(false);
    return out;
}
