import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.components.base

// Focused window title (falls back to its app id). Browsers show only their app name,
// not the tab title. Hidden on an empty workspace.
TextCard {
    // ToplevelManager, not Hyprland.activeToplevel: the latter stays null until the first focus change
    readonly property var window: Compositor.emptyWorkspace ? null : ToplevelManager.activeToplevel
    readonly property string appId: window?.appId ?? ""
    // reading applications re-runs the lookup once the async desktop-entry scan fills it
    readonly property var entry: appId && DesktopEntries.applications.values.length ? DesktopEntries.heuristicLookup(appId) : null
    readonly property bool isBrowser: !!entry && entry.categories.includes("WebBrowser")
    visible: text !== ""
    text: !window ? "" : isBrowser ? entry.name : (window.title || appId)
    icon: String.fromCodePoint(0xf2d0) // Nerd Font window-maximize
    maxTextWidth: 320
}
