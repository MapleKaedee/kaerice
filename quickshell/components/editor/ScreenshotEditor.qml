import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.components.base

// Screenshot editor, opened right after a capture (scripts/screenshot.sh).
// Tools: arrow, marker, crop. Colors: accent / ink / paper. Shapes get the hard ink shadow of the cards.
// Save (Enter / Ctrl+S): one file in ~/Pictures/Screenshots + clipboard. Copy (Ctrl+C): clipboard only.
// Esc / x: discard. Ctrl+Z undoes; A / M / C pick a tool.
Overlay {
    id: root
    name: "editor"
    color: Theme.scrim
    visible: Screenshot.editing !== "" && !Screenshot.hidden
    focusItem: keys
    onDismissed: Screenshot.discard()

    property string tool: "arrow"           // "arrow" | "marker" | "crop"
    property string ink: Theme.accent       // stroke color for new shapes
    property var shapes: []                 // { tool, color, points: [{ x, y }] } in image pixels
    property var history: []                // undo stack: "shape", or the crop rect before a crop
    property var current: null              // shape being drawn
    property rect crop: Qt.rect(0, 0, 0, 0) // visible part of the image, in image pixels
    property bool busy: false               // export running
    property string error: ""               // last failed export

    // fit the cropped image on screen below the toolbar; never upscale
    readonly property real fit: crop.width > 0 ? Math.min(1, (width - 120) / crop.width, (height - 240) / crop.height) : 1

    function undo() {
        const last = history[history.length - 1];
        if (last === undefined) return;
        history = history.slice(0, -1);
        if (last === "shape") shapes = shapes.slice(0, -1);
        else crop = last;
        canvas.requestPaint();
    }

    // save: keep the file (and copy); otherwise copy only
    function finish(save) {
        if (busy || !visible || crop.width <= 0) return; // hidden: grabToImage refuses and never calls back
        busy = true;
        // cropView is the image + shapes at native size, clipped to the crop
        cropView.grabToImage(result => {
            const rendered = Screenshot.editing.replace(/\.png$/, "") + "-render.png";
            if (result.saveToFile(rendered)) {
                Screenshot.finish(rendered, save);
            } else { // Screenshot.finish would delete the capture: stay open, drop the partial file
                Quickshell.execDetached(["rm", "-f", rendered]);
                error = "Not saved: could not write " + rendered;
                busy = false;
            }
        });
    }

    // d: offset for the shadow copy
    function draw(ctx, s, d, color) {
        const p = s.points;
        if (p.length < 2) return;
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineWidth = s.tool === "marker" ? 8 : 6;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(p[0].x + d, p[0].y + d);
        if (s.tool === "marker") {
            for (let i = 1; i < p.length; i++) ctx.lineTo(p[i].x + d, p[i].y + d);
            ctx.stroke();
            return;
        }
        // arrow: shaft stops short of the tip, then a filled head
        const a = p[0], b = p[p.length - 1], head = 26;
        const ang = Math.atan2(b.y - a.y, b.x - a.x);
        ctx.lineTo(b.x - Math.cos(ang) * head * 0.7 + d, b.y - Math.sin(ang) * head * 0.7 + d);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(b.x + d, b.y + d);
        ctx.lineTo(b.x - head * Math.cos(ang - 0.45) + d, b.y - head * Math.sin(ang - 0.45) + d);
        ctx.lineTo(b.x - head * Math.cos(ang + 0.45) + d, b.y - head * Math.sin(ang + 0.45) + d);
        ctx.closePath();
        ctx.fill();
    }

    Connections {
        target: Screenshot
        function onFinishRequested(save) { root.finish(save); }
        // per capture, not per show: the edits survive while screenshot.sh hides the editor
        function onEditingChanged() { root.shapes = []; root.history = []; root.current = null; root.tool = "arrow"; root.busy = false; root.error = ""; }
    }

    // swallow backdrop clicks: a stray click must not discard the edits (Esc closes)
    MouseArea { anchors.fill: parent }

    Item {
        id: keys
        Keys.onEscapePressed: root.dismissed()
        Keys.onReturnPressed: root.finish(true)
        Keys.onEnterPressed: root.finish(true)
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (ctrl && event.key === Qt.Key_Z) root.undo();
            else if (ctrl && event.key === Qt.Key_S) root.finish(true);
            else if (ctrl && event.key === Qt.Key_C) root.finish(false);
            else if (event.key === Qt.Key_A) root.tool = "arrow";
            else if (event.key === Qt.Key_M) root.tool = "marker";
            else if (event.key === Qt.Key_C) root.tool = "crop";
        }
    }

    component ToolButton: Card {
        id: btn
        property int glyph
        property bool active
        signal clicked()
        width: 46; height: 42; offset: Theme.depth(3)
        fill: active ? Theme.accent : Theme.face
        opacity: enabled ? 1 : 0.4
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(btn.glyph)
            color: btn.active ? Theme.accentText : Theme.text
            font.family: Theme.iconFont; font.pixelSize: 18
        }
        MouseArea { anchors.fill: parent; onClicked: btn.clicked() }
    }

    component Swatch: Rectangle {
        id: sw
        width: 32; height: 32
        radius: Theme.corner(6)
        border.width: root.ink === String(sw.color) ? Theme.stroke(5) : Theme.stroke(2)
        border.color: Theme.line
        MouseArea { anchors.fill: parent; onClicked: root.ink = String(sw.color) }
    }

    component Divider: Rectangle { width: Theme.border; height: 34; color: Theme.line }

    Card {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 40
        width: tools.implicitWidth + 28 + offset
        height: 66
        offset: Theme.depth(5)

        Row {
            id: tools
            anchors.centerIn: parent
            spacing: 10

            // Nerd Font: arrow-right f061, paint-brush f1fc, crop f125, undo f0e2, copy f0c5, floppy f0c7, xmark f00d
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf061; active: root.tool === "arrow"; onClicked: root.tool = "arrow" }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf1fc; active: root.tool === "marker"; onClicked: root.tool = "marker" }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf125; active: root.tool === "crop"; onClicked: root.tool = "crop" }
            Divider { anchors.verticalCenter: parent.verticalCenter }
            Swatch { anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
            Swatch { anchors.verticalCenter: parent.verticalCenter; color: Theme.ink }
            Swatch { anchors.verticalCenter: parent.verticalCenter; color: Theme.paper }
            Divider { anchors.verticalCenter: parent.verticalCenter }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf0e2; enabled: root.history.length > 0; onClicked: root.undo() }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf0c5; enabled: !root.busy; onClicked: root.finish(false) }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf0c7; active: true; enabled: !root.busy; onClicked: root.finish(true) }
            ToolButton { anchors.verticalCenter: parent.verticalCenter; glyph: 0xf00d; onClicked: root.dismissed() }
        }
    }

    // here, not a notification: popups sit below this overlay
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: toolbar.y + toolbar.height + 4
        visible: root.error !== ""
        text: root.error
        textFormat: Text.PlainText
        color: Theme.paper
        font.pixelSize: 14; font.bold: true
    }

    // the image, in an ink frame with a hard shadow
    Card {
        anchors.horizontalCenter: parent.horizontalCenter
        y: toolbar.y + toolbar.height + 24 + Math.max(0, (root.height - toolbar.y - toolbar.height - 64 - height) / 2)
        width: view.width + 2 * Theme.border + offset
        height: view.height + 2 * Theme.border + offset
        offset: Theme.depth(8)
        fill: Theme.ink

        Item {
            id: view
            x: Theme.border; y: Theme.border
            width: root.crop.width * root.fit
            height: root.crop.height * root.fit
            clip: true

            // native-size image + shapes, clipped to the crop and scaled to fit; this is what gets exported
            Item {
                id: cropView
                width: root.crop.width
                height: root.crop.height
                scale: root.fit
                transformOrigin: Item.TopLeft
                clip: true

                Item {
                    x: -root.crop.x; y: -root.crop.y
                    width: img.implicitWidth; height: img.implicitHeight

                    Image {
                        id: img
                        source: Screenshot.editing ? "file://" + Screenshot.editing : ""
                        cache: false
                        onStatusChanged: if (status === Image.Ready) root.crop = Qt.rect(0, 0, implicitWidth, implicitHeight)
                    }
                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const all = root.current ? root.shapes.concat([root.current]) : root.shapes;
                            for (const s of all) {
                                root.draw(ctx, s, 4, Theme.ink);
                                root.draw(ctx, s, 0, s.color);
                            }
                        }
                    }
                }
            }

            // crop selection, outside cropView so it is never exported
            Rectangle {
                id: selection
                visible: false
                color: "transparent"
                border.width: Theme.stroke(3); border.color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                property point start

                function toImage(m) { return { x: m.x / root.fit + root.crop.x, y: m.y / root.fit + root.crop.y }; }

                onPressed: mouse => {
                    start = Qt.point(mouse.x, mouse.y);
                    if (root.tool === "crop") {
                        selection.x = mouse.x; selection.y = mouse.y; selection.width = 0; selection.height = 0;
                        selection.visible = true;
                    } else {
                        root.current = { tool: root.tool, color: root.ink, points: [toImage(mouse)] };
                    }
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    if (root.tool === "crop") {
                        const x = Math.max(0, Math.min(mouse.x, width)), y = Math.max(0, Math.min(mouse.y, height));
                        selection.x = Math.min(start.x, x); selection.y = Math.min(start.y, y);
                        selection.width = Math.abs(x - start.x); selection.height = Math.abs(y - start.y);
                    } else if (root.current) {
                        const p = toImage(mouse);
                        // arrows keep only start + end; markers keep the whole path
                        if (root.current.tool === "arrow") root.current.points = [root.current.points[0], p];
                        else root.current.points.push(p);
                        canvas.requestPaint();
                    }
                }
                onReleased: {
                    if (root.tool === "crop") {
                        selection.visible = false;
                        if (selection.width / root.fit < 8 || selection.height / root.fit < 8) return; // a click, not a drag
                        root.history = root.history.concat([root.crop]);
                        root.crop = Qt.rect(root.crop.x + selection.x / root.fit, root.crop.y + selection.y / root.fit,
                                            selection.width / root.fit, selection.height / root.fit);
                    } else if (root.current) {
                        if (root.current.points.length > 1) {
                            root.shapes = root.shapes.concat([root.current]);
                            root.history = root.history.concat(["shape"]);
                        }
                        root.current = null;
                        canvas.requestPaint();
                    }
                }
            }
        }
    }
}
