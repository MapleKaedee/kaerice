import QtQuick
import qs.config
import qs.services
import qs.components.base

// Wallhaven tab of the picker: search, filters, results. Down goes from the search field to the results; Up from their
// first row goes to the filters (Tab, Left/Right there), then to the search field; / does too.
// Enter or a click downloads a result and uses it, D (or its button) only downloads it.
Item {
    id: root
    property int cols: 4
    property bool keyOpen: false

    function enter() {
        searchField.input.forceActiveFocus();
        if (Wallhaven.page === 0 && !Wallhaven.loading) Wallhaven.search();
    }
    function run() {
        typing.stop();
        Wallhaven.query = searchField.input.text;
        Wallhaven.search();
    }
    function toggleKey() {
        keyOpen = !keyOpen;
        keyField.input.text = "";
        (keyOpen ? keyField : searchField).input.forceActiveFocus();
    }

    Timer { id: typing; interval: 600; onTriggered: root.run() } // Wallhaven allows 45 requests per minute
    Connections {
        target: Wallhaven
        function onKeyChanged() { if (root.keyOpen) root.toggleKey(); }
    }

    component Field: Card {
        id: field
        property alias input: input
        property alias echoMode: input.echoMode
        property string placeholder
        signal edited()
        signal accepted()
        height: 44; offset: Theme.depth(3)
        line: input.activeFocus ? Theme.accent : Theme.line
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            color: Theme.text
            font.pixelSize: 16; font.bold: true
            onTextEdited: field.edited()
            onAccepted: field.accepted()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                text: field.placeholder
                color: Theme.muted
                font: input.font
            }
        }
    }

    Column {
        id: header
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 12
            Field {
                id: searchField
                width: parent.width - keyButton.width - parent.spacing
                placeholder: "Search Wallhaven…"
                onEdited: typing.restart()
                onAccepted: root.run()
                Keys.onDownPressed: grid.forceActiveFocus()
            }
            TextButton { // key
                id: keyButton
                anchors.verticalCenter: parent.verticalCenter
                glyph: 0xf084
                label: "API key"
                hot: root.keyOpen
                onClicked: root.toggleKey()
            }
        }

        Column {
            visible: root.keyOpen
            width: parent.width
            spacing: 6
            Row {
                width: parent.width
                spacing: 12
                Field {
                    id: keyField
                    width: parent.width - save.width - parent.spacing - (remove.visible ? remove.width + parent.spacing : 0)
                    placeholder: Wallhaven.key ? "A key is saved. Paste another one to replace it." : "Paste your API key"
                    echoMode: TextInput.Password
                    onAccepted: Wallhaven.setKey(input.text)
                    Keys.onEscapePressed: root.toggleKey()
                }
                TextButton { // check
                    id: save
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: 0xf00c
                    label: Wallhaven.checkingKey ? "Checking…" : "Save"
                    enabled: !Wallhaven.checkingKey && keyField.input.text !== ""
                    onClicked: Wallhaven.setKey(keyField.input.text)
                }
                TextButton { // trash
                    id: remove
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Wallhaven.key !== ""
                    glyph: 0xf1f8
                    label: "Remove"
                    onClicked: Wallhaven.removeKey()
                }
            }
            Text {
                text: Wallhaven.keyError || "From wallhaven.cc/settings/account. Adds Sketchy and NSFW. It stays on this computer."
                color: Wallhaven.keyError ? Theme.highlight : Theme.muted
                font.pixelSize: 13; font.bold: true
            }
        }

        Flow {
            id: filters
            width: parent.width
            spacing: 10
            Keys.onUpPressed: searchField.input.forceActiveFocus()
            Keys.onDownPressed: grid.forceActiveFocus()

            component Switch: TextButton { // one of the three switches of a filter
                required property var modelData
                required property int index
                property string filter
                glyph: modelData.glyph
                label: modelData.label
                hot: Wallhaven.filters[filter][index] === "1"
                onClicked: Wallhaven.toggleFilter(filter, index)
            }

            Row {
                spacing: 10
                Repeater { // globe, star, user
                    id: categories
                    model: [{ label: "General", glyph: 0xf0ac }, { label: "Anime", glyph: 0xf005 }, { label: "People", glyph: 0xf007 }]
                    Switch { filter: "categories" }
                }
            }
            Choice {
                options: [
                    { value: "toplist", label: "Toplist" }, { value: "date_added", label: "Latest" },
                    { value: "random", label: "Random" }, { value: "relevance", label: "Relevance" }
                ]
                value: Wallhaven.filters.sorting
                onPicked: v => Wallhaven.setFilter("sorting", v)
            }
            Choice {
                options: [
                    { value: "", label: "Any size" }, { value: "1920x1080", label: "1080p+" },
                    { value: "2560x1440", label: "1440p+" }, { value: "3840x2160", label: "4K+" }
                ]
                value: Wallhaven.filters.atleast
                onPicked: v => Wallhaven.setFilter("atleast", v)
            }
            Row {
                visible: Wallhaven.key !== ""
                spacing: 10
                Repeater { // shield, eye, triangle-exclamation
                    model: [{ label: "SFW", glyph: 0xf132 }, { label: "Sketchy", glyph: 0xf06e }, { label: "NSFW", glyph: 0xf071 }]
                    Switch { filter: "purity" }
                }
            }
        }
    }

    GridView {
        id: grid
        function download(use) { if (currentItem) Wallhaven.download(currentItem.wid, currentItem.full, use); }
        anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 8; bottom: parent.bottom; bottomMargin: 30 }
        cellWidth: Math.floor(width / root.cols); cellHeight: Math.round(cellWidth * 0.61)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Wallhaven.results
        onAtYEndChanged: if (atYEnd && count > 0) Wallhaven.more()
        onCountChanged: if (currentIndex < 0 && count > 0) currentIndex = 0

        Keys.onReturnPressed: download(true)
        Keys.onEnterPressed: download(true)
        Keys.onUpPressed: event => {
            if (currentIndex < root.cols) categories.itemAt(0).forceActiveFocus();
            else event.accepted = false;
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash) searchField.input.forceActiveFocus();
            else if (event.key === Qt.Key_D && event.modifiers === Qt.NoModifier) download(false);
            else return;
            event.accepted = true;
        }

        delegate: Item {
            id: cell
            required property int index
            required property string wid
            required property string full
            required property string thumb
            required property string resolution
            required property int size
            required property string category
            required property string purity
            readonly property bool selected: GridView.isCurrentItem
            readonly property string file: Wallhaven.owned(wid)
            readonly property bool busy: !!Wallhaven.busy[wid]
            width: grid.cellWidth; height: grid.cellHeight

            WallpaperThumb {
                path: cell.file
                source: cell.thumb
                x: 6; y: 6
                width: parent.width - 12; height: parent.height - 12
                offset: Theme.depth(cell.selected ? 7 : 4)
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: Wallhaven.download(cell.wid, cell.full, true)
            }
            ThumbButton { // spinner, check or download
                anchors { top: parent.top; right: parent.right; topMargin: 14; rightMargin: 22 }
                visible: cell.selected || cell.busy || cell.file !== ""
                glyph: cell.busy ? 0xf110 : cell.file ? 0xf00c : 0xf019
                busy: cell.busy
                enabled: !cell.busy && !cell.file
                onClicked: Wallhaven.download(cell.wid, cell.full, false)
            }
        }
    }

    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        elide: Text.ElideRight
        readonly property var item: grid.currentItem
        text: Wallhaven.error || (Wallhaven.loading ? "Loading…" : !item ? "No results"
            : [(item.index + 1) + " of " + Wallhaven.total, item.resolution, (item.size / 1048576).toFixed(1) + " MB", item.category, item.purity].join("  ·  "))
        color: Wallhaven.error ? Theme.highlight : Theme.muted
        font.pixelSize: 13; font.bold: true
    }
}
