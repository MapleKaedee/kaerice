import Quickshell.Io
import QtQuick

// Network status from systemd-networkd. This machine uses iwd + networkd,
// which Quickshell.Networking (NetworkManager only) can't read.
// shortcut: polls networkctl every 5 s; switch to an event source if the delay bothers you.
TextCard {
    id: root
    text: "NET"
    fill: text === "OFFLINE" ? "#1c1c1c" : "#f2f0eb"
    textColor: text === "OFFLINE" ? "#f2f0eb" : "#1c1c1c"

    Process {
        id: proc
        command: ["networkctl", "list", "--json=short"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                let up = [];
                try {
                    up = JSON.parse(out.text).Interfaces
                        .filter(i => i.Type !== "loopback" && i.OperationalState === "routable");
                } catch (e) {}
                const eth = up.find(i => i.Type === "ether");
                const wifi = up.find(i => i.Type === "wlan");
                root.text = eth ? "ETH" : wifi ? "WIFI " + (wifi.SSID ?? "").slice(0, 14) : "OFFLINE";
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
