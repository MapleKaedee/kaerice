pragma Singleton

import Quickshell
import Quickshell.Services.Polkit

// polkitd takes one agent per session: while another one runs (hyprpolkitagent), this one fails to register.
Singleton {
    readonly property PolkitAgent agent: PolkitAgent {}
}
