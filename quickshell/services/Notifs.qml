pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon (owns org.freedesktop.Notifications) and history.
// Notifications stay in `list` until dismissed; `shown` holds the ids currently shown as popups.
// Do not disturb: no popups except critical ones, but everything still lands in the history.
Singleton {
    id: root
    property int timeout: 5000 // ms a popup stays; critical popups stay until clicked
    property bool dnd: false
    property var shown: []     // ids of notifications currently shown as popups
    property var times: ({})   // id -> "HH:mm" of arrival
    readonly property var list: server.trackedNotifications // oldest first
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
}
