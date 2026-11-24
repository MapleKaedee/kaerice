import QtQuick
import qs.config
import qs.services
import qs.components.base

// Shown while an app records the mic or uses a video source (screen share, webcam): icons + app names.
TextCard {
    visible: Privacy.mic || Privacy.video
    // Nerd Font: microphone f130, video f03d
    icon: [Privacy.mic ? String.fromCodePoint(0xf130) : "", Privacy.video ? String.fromCodePoint(0xf03d) : ""].filter(g => g).join(" ")
    text: Privacy.apps.join(", ")
    maxTextWidth: 180
    fill: Theme.accent
    textColor: Theme.paper
}
