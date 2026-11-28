import Quickshell
import Quickshell.Io
import QtQuick
import qs.config
import qs.components.base

// Autostart (~/.config/autostart, started by systemd at login) and default apps (mimeapps.list), through scripts/apps.sh.
// Both are read when the page opens.
Column {
    id: root
    spacing: 14
    readonly property string script: Quickshell.shellDir + "/scripts/apps.sh"
    // the first type lists the apps to pick from; the app also gets the others it declares
    readonly property var groups: [
        { label: "Web browser", glyph: 0xf0ac, types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] }, // globe
        { label: "File manager", glyph: 0xf07b, types: ["inode/directory"] }, // folder
        { label: "Text editor", glyph: 0xf15c, types: ["text/plain"] }, // file-text
        { label: "Images", glyph: 0xf03e, types: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml"] }, // image
        { label: "Video", glyph: 0xf03d, types: ["video/mp4", "video/x-matroska", "video/webm"] }, // video
        { label: "Music", glyph: 0xf001, types: ["audio/mpeg", "audio/flac", "audio/ogg"] }, // music
        { label: "PDF", glyph: 0xf1c1, types: ["application/pdf"] }, // file-pdf
        { label: "Archives", glyph: 0xf1c6, types: ["application/zip", "application/x-7z-compressed", "application/vnd.rar", "application/x-tar"] } // file-zip
    ]
    property var entries: []    // { file, name, command }
    property var defaults: ({}) // first type -> { app, apps }
    property string open: ""    // label of the group whose list is open
    property string error: ""

    function rows(text) { return text.split("\n").filter(l => l !== "").map(l => l.split("\t")); }
    function run(args) { writer.command = [root.script].concat(args); writer.running = true; }
    function add() {
        if (field.text.trim() === "" || writer.running) return;
        run(["autostart-add", field.text]);
        field.text = "";
    }
    function appName(id) {
        if (!id) return "None";
        const entry = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
        return entry ? entry.name : id;
    }

    Process {
        id: autostart
        running: true
        command: [root.script, "autostart"]
        stdout: StdioCollector { onStreamFinished: root.entries = root.rows(text).map(r => ({ file: r[0], name: r[1], command: r[2] })) }
    }
    Process {
        id: mime
        running: true
        command: [root.script, "defaults"].concat(root.groups.map(g => g.types[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                root.rows(text).forEach(r => d[r[0]] = { app: r[1], apps: r[2] ? r[2].split(";") : [] });
                root.defaults = d;
            }
        }
    }
    Process {
        id: writer
        stderr: StdioCollector { id: failure }
        onExited: code => {
            root.error = code === 0 ? "" : failure.text.trim() || "That did not work";
            autostart.running = true;
            mime.running = true;
        }
    }

    SettingRow { label: "Autostart"; hint: "Commands that run at login, in Mango and Hyprland" }
    Text {
        visible: root.entries.length === 0
        text: "None"
        color: Theme.muted
        font.pixelSize: 13; font.bold: true
    }
    Repeater {
        model: root.entries
        Card {
            id: entry
            required property var modelData
            width: root.width; height: 52; offset: Theme.depth(3)
            Column {
                anchors { left: parent.left; leftMargin: 14; right: remove.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: entry.modelData.name || entry.modelData.file
                    color: Theme.text
                    font.pixelSize: 13; font.bold: true
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: entry.modelData.command
                    color: Theme.muted
                    font.pixelSize: 11; font.bold: true
                }
            }
            TextButton {
                id: remove
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                glyph: 0xf1f8 // trash
                label: "Remove"
                enabled: !writer.running
                onClicked: {
                    field.forceActiveFocus(); // the row goes away: without this Esc stops reaching the panel
                    root.run(["autostart-remove", entry.modelData.file]);
                }
            }
        }
    }
    Row {
        spacing: 12
        Card {
            width: root.width - addButton.width - 12; height: 38; offset: Theme.depth(3)
            line: field.activeFocus ? Theme.accent : Theme.line
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                activeFocusOnTab: true
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                color: Theme.text
                font.pixelSize: 14; font.bold: true
                onAccepted: root.add()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: "A command, like nm-applet --indicator"
                    color: Theme.muted
                    font: field.font
                }
            }
        }
        TextButton {
            id: addButton
            glyph: 0xf067 // plus
            label: "Add"
            enabled: field.text.trim() !== "" && !writer.running
            onClicked: root.add()
        }
    }
    Card {
        visible: root.error !== ""
        width: root.width; height: err.implicitHeight + 20 + offset
        offset: Theme.depth(3)
        fill: Theme.accent
        Text {
            id: err
            x: 12; y: 10
            width: parent.width - 24
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: root.error
            color: Theme.accentText
            font.pixelSize: 13; font.bold: true
        }
    }

    Item { width: 1; height: 4 }
    SettingRow { label: "Default apps"; hint: "What opens links, folders and files" }
    Repeater {
        model: root.groups
        Column {
            id: group
            required property var modelData
            readonly property var info: root.defaults[modelData.types[0]] ?? null
            readonly property bool open: root.open === modelData.label
            width: root.width
            spacing: 8

            SettingRow {
                label: group.modelData.label
                Card { // Tab focuses it; Enter, Space or a click opens the list below
                    id: box
                    width: 280; height: 44; offset: Theme.depth(3)
                    fill: boxArea.containsMouse ? Theme.hover : Theme.face
                    line: activeFocus ? Theme.accent : Theme.line
                    activeFocusOnTab: true
                    function toggle() { root.open = group.open ? "" : group.modelData.label; }
                    Keys.onReturnPressed: toggle()
                    Keys.onEnterPressed: toggle()
                    Keys.onSpacePressed: toggle()

                    Text {
                        id: icon
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        width: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: String.fromCodePoint(group.modelData.glyph)
                        color: Theme.text
                        font.family: Theme.iconFont; font.pixelSize: 17
                    }
                    Text {
                        anchors { left: icon.right; leftMargin: 12; right: chevron.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: group.info ? root.appName(group.info.app) : mime.running ? "Loading" : "Unknown"
                        color: Theme.text
                        font.pixelSize: 13; font.bold: true
                    }
                    Text {
                        id: chevron
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(group.open ? 0xf077 : 0xf078) // chevron-up / chevron-down
                        color: Theme.text
                        font.family: Theme.iconFont; font.pixelSize: 13
                    }
                    MouseArea { id: boxArea; anchors.fill: parent; hoverEnabled: true; onClicked: box.toggle() }
                }
            }
            DeviceList {
                visible: group.open
                nodes: visible && group.info ? group.info.apps : []
                current: group.info ? group.info.app : ""
                glyph: group.modelData.glyph
                label: id => root.appName(id)
                onPicked: id => {
                    box.forceActiveFocus(); // the focused row goes away: without this Esc stops reaching the panel
                    root.open = "";
                    root.run(["default", id].concat(group.modelData.types));
                }
            }
        }
    }
}
