pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "WallhavenApi.js" as Api

// Search and download from wallhaven.cc, used by the wallpaper picker. Nothing is sent before its Wallhaven tab is opened.
// SFW only, unless the user adds an API key there. The key is a secret: it stays in a state file that only this user can
// read (never settings.json, which people share) and is sent as a header from here, never as a command argument.
// The filters are a state file too, so a Sketchy or NSFW choice is not shared either.
Singleton {
    id: root
    property alias results: list  // see Api.parse: wid, full, thumb, purity, category, resolution, size
    property string query: ""
    property var filters: Api.loadFilters(savedFilters.text())
    property int page: 0          // last page loaded, 0 = none yet
    property int lastPage: 0
    property int total: 0
    property bool loading: false
    property string error: ""

    property string key: savedKey.text().trim()
    property bool checkingKey: false
    property string keyError: ""

    property var busy: ({})       // wid -> true while downloading
    property string wanted: ""    // wid to use when its download ends: the last one picked

    property string seed: ""
    property var request: null

    function search() { load(1); }
    function more() { if (!loading && !error && page > 0 && page < lastPage) load(page + 1); }

    function setFilter(name, value) {
        root.filters = Object.assign({}, root.filters, { [name]: value });
        savedFilters.setText(JSON.stringify(root.filters));
        search();
    }
    function toggleFilter(name, i) { setFilter(name, Api.toggle(filters[name], i)); }

    function get(url, key, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) done(x, x.status, x.responseText); };
        x.open("GET", url);
        if (key) x.setRequestHeader("X-API-Key", key);
        x.send();
        return x;
    }

    function stop() {
        const old = request;
        request = null; // first: abort() calls back
        old?.abort();
        loading = false;
    }

    function load(n) {
        stop();
        loading = true;
        error = "";
        request = get(Api.searchUrl(query, filters, key, n, seed), key, (x, status, text) => {
            if (x !== root.request) return; // replaced by a newer search
            root.request = null;
            root.loading = false;
            const r = status === 200 ? Api.parse(text) : null;
            if (!r) { root.error = status === 200 ? "Wallhaven sent an answer that could not be read." : Api.errorText(status); return; }
            if (n === 1) list.clear();
            r.items.forEach(i => list.append(i));
            root.page = r.page;
            root.lastPage = r.lastPage;
            root.total = r.total;
            root.seed = r.seed;
        });
    }

    // tried against Wallhaven first, saved only when accepted
    function setKey(text) {
        const k = text.trim();
        keyError = "";
        if (!Api.isKey(k)) { keyError = "That does not look like an API key."; return; }
        checkingKey = true;
        get(Api.checkUrl, k, (x, status) => {
            root.checkingKey = false;
            if (status === 200) storeKey(k); else root.keyError = Api.errorText(status);
        });
    }
    function removeKey() {
        keyError = "";
        storeKey("");
        setFilter("purity", "100");
    }
    function storeKey(k) {
        root.key = k;
        keyWriter.running = true;
    }

    // path of the local file, "" when not downloaded
    function owned(wid) { return Wallpaper.images.find(p => Api.isFileOf(Wallpaper.base(p), wid)) ?? ""; }

    function download(wid, url, use) {
        if (use) wanted = wid;
        const have = owned(wid);
        if (have) { if (use) Wallpaper.apply(have); return; }
        if (busy[wid]) return;
        root.busy = Object.assign({}, busy, { [wid]: true });
        error = "";
        job.createObject(root, { wid: wid, url: url, file: Wallpaper.downloads + "/" + Api.fileName(url), running: true });
    }

    Connections {
        target: Wallpaper
        function onSourceChanged() { root.wanted = ""; } // another choice came in between
    }

    ListModel { id: list }

    Timer { // no answer
        interval: 20000
        running: root.loading
        onTriggered: { root.stop(); root.error = Api.errorText(0); }
    }

    Component {
        id: job
        Process {
            id: download
            required property string wid
            required property string url
            required property string file
            // a .part file first, so half an image never shows up as a wallpaper
            command: ["sh", "-c", `
                mkdir -p "\${2%/*}" && curl -fsSL --proto =https --max-time 300 --max-filesize 100M -o "$2.part" -- "$1" && mv -- "$2.part" "$2" && exit 0
                rm -f -- "$2.part"; exit 1`, "sh", url, file]
            onExited: code => {
                const left = Object.assign({}, root.busy);
                delete left[wid];
                root.busy = left;
                if (code === 0) {
                    Wallpaper.scan();
                    if (root.wanted === wid) Wallpaper.apply(file);
                } else root.error = "The download of " + Api.fileName(url) + " failed.";
                download.destroy();
            }
        }
    }

    FileView {
        id: savedFilters
        path: Quickshell.statePath("wallhaven-filters")
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: savedKey
        path: Quickshell.statePath("wallhaven-key")
        blockLoading: true
        printErrors: false
    }
    Process { // not FileView: its files are readable by everyone
        id: keyWriter
        command: ["sh", "-c", `umask 077; mkdir -p "\${1%/*}" && cat > "$1.new" && mv -- "$1.new" "$1"`, "sh", savedKey.path]
        property string written
        stdinEnabled: true
        onStarted: { written = root.key; write(written); stdinEnabled = false; }
        onExited: { stdinEnabled = true; if (written !== root.key) running = true; } // changed while writing
    }
}
