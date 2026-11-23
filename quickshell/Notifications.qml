import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon (owns org.freedesktop.Notifications): popups at top-right + a history panel.
// Panel (SUPER+N or the bell card): qs -c kaerice ipc call notifications toggle
// Notifications stay in the history until dismissed there; popups hide after `timeout`.
// Do not disturb: no popups except critical ones, but everything still lands in the history.
Scope {
    id: root
    property int timeout: 5000 // ms; critical popups stay until clicked
    property bool dnd: false
    property bool panelOpen: false
    property var shown: []     // ids of notifications currently shown as popups
    property var times: ({})   // id -> "HH:mm" of arrival
    readonly property int count: server.trackedNotifications.values.length

    function hide(id) { root.shown = root.shown.filter(x => x !== id); }

    // run the default action (if any), then remove the notification
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        n.dismiss();
    }

    // copy first: dismissing changes the model while we iterate
    function clearAll() { server.trackedNotifications.values.slice().forEach(n => n.dismiss()); }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        onNotification: n => {
            root.times[n.id] = Qt.formatDateTime(new Date(), "HH:mm");
            n.tracked = true;
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.shown = root.shown.concat([n.id]);
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.panelOpen = !root.panelOpen; }
        function toggleDnd(): void { root.dnd = !root.dnd; }
        function clear(): void { root.clearAll(); }
    }

    // popups
    PanelWindow {
        visible: root.shown.length > 0
        anchors { top: true; right: true }
        margins { top: 8; right: 14 }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        implicitWidth: 360
        implicitHeight: popups.implicitHeight
        color: "transparent"

        Column {
            id: popups
            width: parent.width
            spacing: 10

            Repeater {
                model: server.trackedNotifications

                NotificationCard {
                    id: popup
                    required property Notification modelData
                    readonly property int nid: modelData.id
                    notification: modelData
                    width: popups.width
                    visible: root.shown.indexOf(nid) >= 0
                    onActivated: root.activate(modelData)

                    Timer {
                        running: !popup.critical
                        interval: root.timeout
                        onTriggered: root.hide(popup.nid)
                    }
                    Component.onDestruction: root.hide(popup.nid)
                }
            }
        }
    }

    // history panel
    PanelWindow {
        visible: root.panelOpen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "kaerice-notifications"

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        // click outside closes
        MouseArea { anchors.fill: parent; onClicked: root.panelOpen = false }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.panelOpen = false
        }

        Card {
            x: parent.width - width - 14
            y: 60
            width: 400
            height: col.implicitHeight + 24 + offset
            offset: 6

            MouseArea { anchors.fill: parent } // swallow clicks inside the panel

            Column {
                id: col
                x: 12; y: 12
                width: parent.width - 24
                spacing: 10

                // header: title, do-not-disturb, clear all
                Item {
                    width: parent.width
                    height: 36

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        color: "#1c1c1c"
                        font.pixelSize: 18; font.bold: true
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        Card {
                            width: 38; height: 36; offset: 3
                            fill: root.dnd ? "#e8335a" : "#f2f0eb"
                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(root.dnd ? 0xf1f6 : 0xf0f3) // bell-slash / bell
                                color: root.dnd ? "#f2f0eb" : "#1c1c1c"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.dnd = !root.dnd }
                        }
                        Card {
                            visible: root.count > 0
                            width: 38; height: 36; offset: 3
                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(0xf1f8) // trash
                                color: "#1c1c1c"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.clearAll() }
                        }
                    }
                }

                Text {
                    visible: root.count === 0 || root.dnd
                    text: root.count === 0 ? "No notifications" : "Do not disturb is on"
                    color: "#1c1c1c"
                    opacity: 0.75
                    font.pixelSize: 13
                }

                ListView {
                    id: history
                    width: parent.width
                    height: Math.min(contentHeight, 560)
                    visible: count > 0
                    clip: true
                    spacing: 10
                    // newest first
                    model: server.trackedNotifications.values.slice().reverse()

                    delegate: NotificationCard {
                        required property var modelData
                        notification: modelData
                        width: history.width
                        time: root.times[modelData.id] || ""
                        closable: true
                        onActivated: root.activate(modelData)
                    }
                }
            }
        }
    }
}
