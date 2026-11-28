.pragma library

// passwd: /etc/passwd. People who can log in: uid 1000-59999 and a real shell.
function users(passwd) {
    const out = [];
    for (const line of passwd.split("\n")) {
        const f = line.split(":");
        if (f.length < 7) continue;
        const uid = Number(f[2]);
        if (uid < 1000 || uid > 59999 || /(nologin|false)$/.test(f[6])) continue;
        out.push({ user: f[0], name: f[4].split(",")[0].trim() || f[0] });
    }
    return out;
}

// listing: `grep -H` lines "<path>:<Key>=<Value>" of the session files. The first value of a key wins:
// it is the one of [Desktop Entry], which comes first.
function sessions(listing) {
    const files = {};
    for (const line of listing.split("\n")) {
        const colon = line.indexOf(":");
        const eq = line.indexOf("=", colon);
        if (colon < 0 || eq < 0) continue;
        const file = line.slice(0, colon).split("/").pop();
        const key = line.slice(colon + 1, eq);
        const entry = files[file] || (files[file] = { file: file });
        if (!(key in entry)) entry[key] = line.slice(eq + 1);
    }
    return Object.keys(files).map(k => files[k])
        .filter(e => e.Exec && e.Hidden !== "true" && e.NoDisplay !== "true")
        .map(e => ({ file: e.file, name: e.Name || e.file, exec: e.Exec, desktops: e.DesktopNames || "" }))
        .sort((a, b) => a.name.localeCompare(b.name));
}

function pick(list, saved) {
    const i = list.findIndex(s => s.file === saved);
    if (i >= 0) return i;
    return Math.max(0, list.findIndex(s => s.file === "mango.desktop"));
}

function launch(session) {
    const environment = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + session.file.replace(/\.desktop$/, "")];
    const desktops = session.desktops.split(";").filter(d => d !== "").join(":");
    if (desktops) environment.push("XDG_CURRENT_DESKTOP=" + desktops);
    return { command: ["/bin/sh", "-c", session.exec], environment: environment };
}
