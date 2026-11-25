import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Control center (at the bar, opened from the distro card): profile + lock/power, brightness and volume
// sliders, network / Bluetooth / output / input tiles (the last two open a device list; their icons mute),
// quick toggles (Silent, Awake, app Dark mode), disk and window count.
Overlay {
    id: root
    name: "control-center"
    visible: Ui.controlCenter
    onDismissed: Ui.controlCenter = false
    onVisibleChanged: if (!visible) openDevices = ""

    property string openDevices: "" // device list shown: "" | "output" | "input"
    readonly property int panelWidth: 460
    readonly property int gap: 12
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property int windowCount: Hyprland.toplevels.values.length

    // close the panel, then run an action that opens something else
    function then(fn) { Ui.controlCenter = false; fn(); }

    // square icon button with a hard shadow
    component SquareButton: Card {
        id: sq
        property int glyph
        signal clicked()
        width: 48; height: 48; offset: Theme.depth(3)
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(sq.glyph)
            color: Theme.text
            font.family: Theme.iconFont; font.pixelSize: 18
        }
        MouseArea { anchors.fill: parent; onClicked: sq.clicked() }
    }

    // icon box + title + subtitle; the icon box turns accent while active. With iconButton the icon box clicks on its own.
    component Tile: Card {
        id: tile
        property int glyph
        property string title
        property string subtitle
        property bool active
        property bool iconButton: false
        signal clicked()
        signal iconClicked()
        width: (root.panelWidth - 32 - root.gap) / 2; height: 66; offset: Theme.depth(3)
        MouseArea { anchors.fill: parent; onClicked: tile.clicked() } // first: below the icon's
        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 12
            Rectangle {
                width: 42; height: 42
                radius: Theme.corner(6)
                color: tile.active ? Theme.accent : Theme.face
                border.width: Theme.stroke(2); border.color: Theme.line
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(tile.glyph)
                    color: tile.active ? Theme.accentText : Theme.text
                    font.family: Theme.iconFont; font.pixelSize: 17
                }
                MouseArea { anchors.fill: parent; enabled: tile.iconButton; onClicked: tile.iconClicked() }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: tile.width - tile.offset - 76
                    elide: Text.ElideRight
                    text: tile.title
                    color: Theme.text
                    font.pixelSize: 14; font.bold: true
                }
                Text {
                    width: tile.width - tile.offset - 76
                    elide: Text.ElideRight
                    text: tile.subtitle
                    color: Theme.muted
                    font.pixelSize: 12; font.bold: true
                }
            }
        }
    }

    // icon over a short label; accent fill while on
    component Toggle: Card {
        id: tog
        property int glyph
        property string label
        property bool active
        signal clicked()
        width: (root.panelWidth - 32 - 4 * root.gap) / 5; height: 64; offset: Theme.depth(3)
        fill: active ? Theme.accent : Theme.face
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String.fromCodePoint(tog.glyph)
                color: tog.active ? Theme.accentText : Theme.text
                font.family: Theme.iconFont; font.pixelSize: 18
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tog.label
                color: tog.active ? Theme.accentText : Theme.text
                font.pixelSize: 11; font.bold: true
            }
        }
        MouseArea { anchors.fill: parent; onClicked: tog.clicked() }
    }

    // slider row: glyph (clickable), bar, percent
    component LevelRow: Row {
        id: lvl
        property int glyph
        property real value
        property string valueText
        property alias step: slider.step
        signal moved(real v)
        signal iconClicked()
        width: root.panelWidth - 32
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            text: String.fromCodePoint(lvl.glyph)
            color: Theme.text
            font.family: Theme.iconFont; font.pixelSize: 18
            MouseArea { anchors.fill: parent; onClicked: lvl.iconClicked() }
        }
        LevelSlider {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            width: lvl.width - 24 - 52 - 2 * lvl.spacing
            value: lvl.value
            onMoved: v => lvl.moved(v)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: lvl.valueText
            color: Theme.text
            font.pixelSize: 14; font.bold: true
        }
    }

    Card {
        x: BarLayout.panelX("control", width, parent.width)
        y: BarLayout.panelY(height, parent.height)
        width: root.panelWidth - 6 + offset // 6: the default shadow; the content keeps its width
        height: col.implicitHeight + 32 + offset
        offset: Theme.depth(6)

        MouseArea { anchors.fill: parent } // swallow clicks inside the panel

        Column {
            id: col
            x: 16; y: 16
            width: root.panelWidth - 32
            spacing: root.gap

            // profile, lock, power
            Item {
                width: parent.width; height: 60
                Avatar { id: avatar; width: 60; height: 60 }
                Column {
                    anchors { left: avatar.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Text {
                        text: Account.name
                        color: Theme.text
                        font.pixelSize: 18; font.bold: true
                    }
                    Text {
                        text: (Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland") + (SysStats.uptime ? "  ·  " + SysStats.uptimeText : "")
                        color: Theme.muted
                        font.pixelSize: 12; font.bold: true
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    SquareButton { glyph: 0xf013; onClicked: root.then(() => Ui.settings = true) } // gear
                    SquareButton { glyph: 0xf023; onClicked: root.then(() => Lock.lock()) }        // lock
                    SquareButton { glyph: 0xf011; onClicked: root.then(() => Ui.power = true) }   // power
                }
            }

            LevelRow {
                glyph: 0xf185 // sun
                value: Math.max(0, Brightness.percent) / 100
                valueText: Brightness.percent < 0 ? "--" : Brightness.percent + "%"
                onMoved: v => Brightness.set(v * 100)
            }
            LevelRow {
                glyph: Audio.muted ? 0xf026 : 0xf028
                value: Audio.volume
                valueText: Audio.muted ? "MUTE" : Audio.percent + "%"
                step: Audio.stepSize
                onMoved: v => Audio.setVolume(v)
            }

            // volume mixer: one row per app that plays audio; click the icon to mute it
            Column {
                visible: Audio.apps.length > 0
                width: parent.width
                spacing: 8
                Repeater {
                    model: Audio.apps
                    Row {
                        id: app
                        required property var modelData
                        readonly property var audio: modelData.nodes[0]?.audio ?? null
                        readonly property bool muted: audio?.muted ?? false
                        width: parent.width
                        spacing: 12
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 24
                            opacity: app.muted ? 0.35 : 1
                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(app.modelData.id)?.icon ?? "", true)
                                || Quickshell.iconPath("application-x-executable")
                            MouseArea { anchors.fill: parent; onClicked: Audio.toggleAppMute(app.modelData) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 84
                            elide: Text.ElideRight
                            text: app.modelData.name
                            color: Theme.text
                            font.pixelSize: 13; font.bold: true
                        }
                        LevelSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - 84 - 52 - 3 * parent.spacing
                            height: 18
                            value: app.audio?.volume ?? 0
                            step: Audio.stepSize
                            onMoved: v => Audio.setAppVolume(app.modelData, v)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            horizontalAlignment: Text.AlignRight
                            text: app.muted ? "MUTE" : Math.round((app.audio?.volume ?? 0) * 100) + "%"
                            color: Theme.text
                            font.pixelSize: 13; font.bold: true
                        }
                    }
                }
            }

            Grid {
                columns: 2
                spacing: root.gap
                Tile {
                    // ethernet port / wifi off / wifi
                    glyph: Network.kind === "eth" ? 0xf0200 : Network.online ? 0xf1eb : 0xf05aa
                    title: Network.kind === "eth" ? "Ethernet" : "Wi-Fi"
                    subtitle: Network.kind === "eth" ? "Connected" : Network.kind === "offline" ? "Offline" : Network.kind === "unavailable" ? "Unavailable" : Network.label
                    active: Network.online
                    onClicked: root.then(() => Ui.wifi = true)
                }
                Tile {
                    glyph: 0xf293 // bluetooth
                    title: "Bluetooth"
                    subtitle: !root.adapter ? "No adapter" : !root.adapter.enabled ? "Off"
                        : root.btConnected.length ? root.btConnected.map(d => d.name).join(", ") : "On"
                    active: root.adapter?.enabled ?? false
                    onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                }
                Tile {
                    glyph: Audio.muted ? 0xf026 : 0xf028
                    title: Audio.shortName(Audio.sink) || "No output"
                    subtitle: Audio.muted ? "Muted" : Audio.percent + "%"
                    active: !Audio.muted
                    iconButton: true
                    onIconClicked: Audio.toggleMute()
                    onClicked: root.openDevices = root.openDevices === "output" ? "" : "output"
                }
                Tile {
                    glyph: Audio.micMuted ? 0xf131 : 0xf130
                    title: Audio.shortName(Audio.source) || "No input"
                    subtitle: Audio.micMuted ? "Muted" : Audio.micPercent + "%"
                    active: !Audio.micMuted
                    iconButton: true
                    onIconClicked: Audio.toggleMicMute()
                    onClicked: root.openDevices = root.openDevices === "input" ? "" : "input"
                }
            }

            // level and device list of the opened tile
            Card {
                id: devices
                readonly property bool output: root.openDevices === "output"
                visible: root.openDevices !== ""
                width: parent.width; height: devicesCol.implicitHeight + 24 + offset; offset: Theme.depth(3)
                Column {
                    id: devicesCol
                    x: 14; y: 12
                    width: parent.width - 28
                    spacing: 12
                    Item {
                        width: parent.width; height: 22
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: devices.output ? "Output" : "Input"
                            color: Theme.text
                            font.pixelSize: 15; font.bold: true
                        }
                        IconButton {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: String.fromCodePoint(0xf00d) // xmark
                            onClicked: root.openDevices = ""
                        }
                    }
                    LevelRow {
                        width: parent.width
                        glyph: devices.output ? (Audio.muted ? 0xf026 : 0xf028) : (Audio.micMuted ? 0xf131 : 0xf130)
                        value: devices.output ? Audio.volume : Audio.micVolume
                        valueText: (devices.output ? Audio.muted : Audio.micMuted) ? "MUTE" : (devices.output ? Audio.percent : Audio.micPercent) + "%"
                        step: Audio.stepSize
                        onIconClicked: devices.output ? Audio.toggleMute() : Audio.toggleMicMute()
                        onMoved: v => devices.output ? Audio.setVolume(v) : Audio.setMicVolume(v)
                    }
                    Flickable { // up to four devices, then it scrolls
                        width: parent.width; height: Math.min(contentHeight, 4 * 60 - 8)
                        contentHeight: deviceList.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        DeviceList {
                            id: deviceList
                            nodes: devices.output ? Audio.sinks : Audio.sources
                            current: devices.output ? Audio.sink : Audio.source
                            glyph: devices.output ? 0xf028 : 0xf130
                            onPicked: node => devices.output ? Audio.useSink(node) : Audio.useSource(node)
                        }
                    }
                }
            }

            Row {
                spacing: root.gap
                Toggle { glyph: 0xf1f6; label: "Silent"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
                Toggle { glyph: 0xf0f4; label: "Awake"; active: Idle.keepAwake; onClicked: Idle.keepAwake = !Idle.keepAwake }
                // apps only (GTK color-scheme); the shell keeps its theme
                Toggle { glyph: 0xf186; label: "Dark"; active: AppTheme.dark; onClicked: AppTheme.setDark(!AppTheme.dark) }
                Toggle {
                    glyph: 0xf030; label: "Capture"
                    onClicked: root.then(() => Screenshot.take("region"))
                }
                Toggle { glyph: 0xf03e; label: "Wallpaper"; onClicked: root.then(() => Ui.wallpaperPicker = true) }
            }

            Grid {
                columns: 2
                spacing: root.gap
                Tile {
                    glyph: 0xf0a0 // hard drive
                    title: "/"
                    subtitle: SysStats.diskTotalGb
                        ? SysStats.diskUsedGb.toFixed(0) + " / " + SysStats.diskTotalGb.toFixed(0) + " GB (" + Math.round(SysStats.disk * 100) + "%)"
                        : "--"
                }
                Tile {
                    glyph: 0xf2d2 // window-restore
                    title: root.windowCount + (root.windowCount === 1 ? " window" : " windows")
                    subtitle: "Overview"
                    onClicked: root.then(() => Switcher.toggleOverview())
                }
            }
        }
    }
}
