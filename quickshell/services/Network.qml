pragma Singleton

import Quickshell
import QtQuick
import "NetworkState.js" as State

Singleton {
    readonly property var view: State.view(Backend.topics.network, Backend.down)
    readonly property string kind: view.kind     // "eth" | "wifi" | "offline" | "unavailable"
    readonly property string label: view.label   // "ETH", the Wi-Fi SSID, "OFFLINE", "N/A"
    readonly property bool online: kind === "eth" || kind === "wifi"
}
