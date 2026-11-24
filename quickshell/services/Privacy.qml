pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Mic and video use, from Pipewire links: a mic (AudioSource) feeding an app's input stream,
// or a video source (screen cast, webcam) feeding anything. `apps`: names of those consumers.
Singleton {
    id: root
    readonly property var links: Pipewire.linkGroups.values
    readonly property var micUsers: links.filter(l => l.source?.type === PwNodeType.AudioSource && l.target?.type === PwNodeType.AudioInStream).map(l => l.target)
    readonly property var videoUsers: links.filter(l => l.source?.type === PwNodeType.VideoSource).map(l => l.target).filter(n => n)
    readonly property bool mic: micUsers.length > 0
    readonly property bool video: videoUsers.length > 0
    readonly property var apps: [...new Set(micUsers.concat(videoUsers).map(n => n.properties["application.name"] || n.description || n.name))]

    // binds the consumer nodes so their properties (application.name) are filled
    PwObjectTracker { objects: root.micUsers.concat(root.videoUsers) }
}
