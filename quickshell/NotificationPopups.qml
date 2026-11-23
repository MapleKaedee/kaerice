import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon (owns org.freedesktop.Notifications) + popup cards at top-right.
Scope {
    id: root
    property int timeout: 5000 // ms; critical notifications stay until clicked

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        onNotification: n => n.tracked = true
    }

    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        margins { top: 8; right: 14 }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        implicitWidth: 360
        implicitHeight: list.implicitHeight
        color: "transparent"

        Column {
            id: list
            width: parent.width
            spacing: 10

            Repeater {
                model: server.trackedNotifications

                Card {
                    id: card
                    required property Notification modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    width: list.width
                    height: content.implicitHeight + 24 + offset
                    fill: critical ? "#e8335a" : "#f2f0eb"

                    Column {
                        id: content
                        x: 12; y: 12
                        width: parent.width - 24
                        spacing: 4

                        Text {
                            width: parent.width
                            text: card.modelData.appName
                            color: card.critical ? "#f2f0eb" : "#e8335a"
                            font.bold: true; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.summary
                            color: card.critical ? "#f2f0eb" : "#1c1c1c"
                            font.bold: true; font.pixelSize: 15
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: card.modelData.body
                            color: card.critical ? "#f2f0eb" : "#1c1c1c"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }

                    // click = run default action (if any) and dismiss
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const def = card.modelData.actions.find(a => a.identifier === "default");
                            if (def) def.invoke();
                            card.modelData.dismiss();
                        }
                    }

                    Timer {
                        running: !card.critical
                        interval: root.timeout
                        onTriggered: card.modelData.expire()
                    }
                }
            }
        }
    }
}
