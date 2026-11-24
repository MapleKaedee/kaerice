pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Emoji list from config/emoji.tsv (unicode.org emoji-test.txt, fully-qualified, no skin tones,
// filtered to what Noto Color Emoji draws; columns: emoji, name, keywords) and the recently used ones.
// pick() copies to the clipboard; recent is a state file (newest first, max 24).
Singleton {
    id: root
    readonly property var all: list.text().split("\n").filter(l => l).map(l => {
        const [e, name, keys] = l.split("\t");
        return { e: e, name: name, hay: (name + " " + keys).toLowerCase() };
    })
    property var recent: parse(saved.text())
    readonly property var recentItems: recent.map(e => all.find(x => x.e === e)).filter(x => x)

    function parse(t) { try { return JSON.parse(t) || []; } catch (e) { return []; } }

    // every word must match the name or keywords; names starting with the query come first
    function search(query) {
        const q = query.trim().toLowerCase(), words = q.split(/\s+/);
        return all.filter(x => words.every(w => x.hay.includes(w)))
            .sort((a, b) => (b.name.toLowerCase().startsWith(q) ? 1 : 0) - (a.name.toLowerCase().startsWith(q) ? 1 : 0));
    }

    function pick(e) {
        Quickshell.execDetached(["wl-copy", e]);
        root.recent = [e].concat(root.recent.filter(x => x !== e)).slice(0, 24);
        saved.setText(JSON.stringify(root.recent));
    }

    FileView { id: list; path: Quickshell.shellDir + "/config/emoji.tsv"; blockLoading: true }
    FileView { id: saved; path: Quickshell.statePath("emoji-recent"); blockLoading: true; printErrors: false }
}
