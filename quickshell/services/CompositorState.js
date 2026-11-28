.pragma library

// env: { desktop: XDG_CURRENT_DESKTOP, mango: MANGO_INSTANCE_SIGNATURE, hyprland: HYPRLAND_INSTANCE_SIGNATURE }.
// The desktop name comes first: the systemd environment keeps the signature of a session that already ended.
function detect(env) {
    const names = (env.desktop || "").toLowerCase().split(":");
    for (const n of names) if (n === "mango" || n === "hyprland") return n;
    return env.mango ? "mango" : env.hyprland ? "hyprland" : "";
}
