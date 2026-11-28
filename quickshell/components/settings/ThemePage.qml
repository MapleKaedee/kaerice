import QtQuick
import qs.config
import qs.services
import qs.components.base
import qs.components.wallpaper

// Wallpaper, light or dark (shell and apps separately), accent color, card shape, cursor.
Column {
    id: root
    spacing: 14
    readonly property var modes: [{ value: false, label: "Light" }, { value: true, label: "Dark" }]
    readonly property string accent: String(Theme.accent) // "#rrggbb"
    function setAccent(hex) { Settings.set("theme.accent", hex); }

    Component.onCompleted: {
        Wallpaper.scan(); // picks up new files
        Cursor.refresh();
    }

    SettingRow { label: "Wallpaper"; hint: "SUPER+Y opens them all, and Wallhaven" }
    ListView { // Tab focuses it, Left/Right or a click pick
        id: strip
        width: parent.width; height: 108
        orientation: ListView.Horizontal
        spacing: 10
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        activeFocusOnTab: true
        keyNavigationEnabled: false
        model: Wallpaper.images
        readonly property int current: Wallpaper.images.findIndex(i => Wallpaper.base(i) === Wallpaper.base(Wallpaper.source))
        function show() { if (current >= 0) positionViewAtIndex(current, ListView.Contain); }
        function move(delta) {
            const to = Wallpaper.images[current + delta];
            if (to) Wallpaper.apply(to);
        }
        onCurrentChanged: show()
        onCountChanged: show()
        Keys.onLeftPressed: move(-1)
        Keys.onRightPressed: move(1)

        delegate: WallpaperThumb {
            id: thumb
            required property string modelData
            path: modelData
            width: 178; height: strip.height
            offset: Theme.depth(active && strip.activeFocus ? 7 : 4)
            MouseArea { anchors.fill: parent; onClicked: Wallpaper.apply(thumb.path) }
        }
    }

    SettingRow {
        label: "Shell mode"
        Choice {
            options: root.modes
            value: Theme.dark
            onPicked: v => Settings.set("theme.dark", v)
        }
    }
    SettingRow {
        label: "App mode"
        hint: "The same as Dark in the control center"
        Choice {
            options: root.modes
            value: AppTheme.dark
            onPicked: v => AppTheme.setDark(v)
        }
    }

    SettingRow {
        label: "Accent"
        Choice {
            options: Theme.accents.map(c => ({ value: c, label: "", color: c }))
            value: root.accent
            onPicked: v => root.setAccent(v)
        }
    }
    SettingRow {
        label: "Own accent"
        hint: "Six hex digits. Text on the accent turns light or dark by itself."
        Card {
            width: 130; height: 38; offset: Theme.depth(3)
            line: hex.activeFocus ? Theme.accent : Theme.line
            TextInput {
                id: hex
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                activeFocusOnTab: true
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                color: Theme.text
                font.pixelSize: 14; font.bold: true
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{6}/ }
                Component.onCompleted: text = root.accent
                onTextEdited: if (acceptableInput) root.setAccent("#" + text.slice(-6).toLowerCase())
                onActiveFocusChanged: if (!activeFocus) text = root.accent // drops half-typed input
                Connections {
                    target: root
                    function onAccentChanged() { if (!hex.activeFocus) hex.text = root.accent; }
                }
            }
        }
    }

    SettingRow {
        label: "Corners"
        Stepper {
            values: [0, 2, 4, 6, 8, 10, 12, 14, 16]
            value: Theme.radius
            format: v => v + " px"
            onPicked: v => Settings.set("theme.radius", v)
        }
    }
    SettingRow {
        label: "Borders"
        Stepper {
            values: [1, 2, 3, 4, 5]
            value: Theme.border
            format: v => v + " px"
            onPicked: v => Settings.set("theme.border", v)
        }
    }
    SettingRow {
        label: "Shadows"
        Stepper {
            values: [0, 2, 3, 4, 5, 6, 8]
            value: Theme.shadow
            format: v => v ? v + " px" : "Off"
            onPicked: v => Settings.set("theme.shadow", v)
        }
    }

    SettingRow {
        label: "Cursor"
        hint: !Cursor.state ? "Unavailable"
            : Cursor.failed ? "The cursor could not be changed"
            : "For all apps. An app that is already open may need to be opened again."
        TextButton {
            visible: Cursor.state !== null
            enabled: !Cursor.installing
            glyph: 0xf067 // plus
            label: "Install"
            onClicked: Cursor.install()
        }
    }
    Card { // Tab focuses it; Enter, Space or a click opens the list below
        id: cursorBox
        property bool open: false
        visible: Cursor.state !== null
        width: parent.width; height: 44; offset: Theme.depth(3)
        fill: cursorArea.containsMouse ? Theme.hover : Theme.face
        line: activeFocus ? Theme.accent : Theme.line
        activeFocusOnTab: true
        Keys.onReturnPressed: open = !open
        Keys.onEnterPressed: open = !open
        Keys.onSpacePressed: open = !open

        Text {
            id: cursorIcon
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: 26
            horizontalAlignment: Text.AlignHCenter
            text: String.fromCodePoint(0xf245) // mouse-pointer
            color: Theme.text
            font.family: Theme.iconFont; font.pixelSize: 17
        }
        Text {
            anchors { left: cursorIcon.right; leftMargin: 12; right: chevron.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            text: Cursor.theme || "None"
            color: Theme.text
            font.pixelSize: 13; font.bold: true
        }
        Text {
            id: chevron
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            text: String.fromCodePoint(cursorBox.open ? 0xf077 : 0xf078) // chevron-up / chevron-down
            color: Theme.text
            font.family: Theme.iconFont; font.pixelSize: 13
        }
        MouseArea { id: cursorArea; anchors.fill: parent; hoverEnabled: true; onClicked: cursorBox.open = !cursorBox.open }
    }
    DeviceList {
        visible: cursorBox.visible && cursorBox.open
        nodes: visible ? Cursor.themes : []
        current: Cursor.theme
        glyph: 0xf245 // mouse-pointer
        label: name => name
        onPicked: name => {
            cursorBox.forceActiveFocus(); // the focused row goes away: without this Esc stops reaching the panel
            cursorBox.open = false;
            // a theme without a copy reports the size apps get, which cursor.set may refuse (it takes 16..96)
            Cursor.set(name, Math.min(Math.max(Cursor.size, 16), 96));
        }
    }
    SettingRow {
        visible: Cursor.theme !== ""
        label: "Cursor size"
        Stepper {
            values: [16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 96]
            value: Cursor.size
            format: v => v + " px"
            onPicked: v => Cursor.set(Cursor.theme, v)
        }
    }
}
