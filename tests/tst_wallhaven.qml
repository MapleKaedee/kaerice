import QtQuick
import QtTest
import "../quickshell/services/WallhavenApi.js" as Api

TestCase {
    name: "WallhavenApi"
    readonly property var defaults: Api.loadFilters("")

    // query part of a URL -> { name: value }
    function params(url) {
        const out = {};
        url.split("?")[1].split("&").forEach(p => { const i = p.indexOf("="); out[p.slice(0, i)] = decodeURIComponent(p.slice(i + 1)); });
        return out;
    }

    function item(changes) {
        return Object.assign({
            id: "7jmgey", purity: "sfw", category: "general", resolution: "3840x2160", file_size: 1342922,
            path: "https://w.wallhaven.cc/full/7j/wallhaven-7jmgey.png", thumbs: { large: "https://th.wallhaven.cc/lg/7j/7jmgey.jpg" }
        }, changes);
    }
    function answer(items, meta) { return JSON.stringify({ data: items, meta: Object.assign({ current_page: 1, last_page: 39, total: 919, seed: null }, meta) }); }

    function test_search_url() {
        const p = params(Api.searchUrl("", defaults, "", 1, ""));
        compare(p, { categories: "111", purity: "100", sorting: "toplist", topRange: "1M", atleast: "1920x1080", page: "1" });
    }
    function test_search_url_escapes_the_query() {
        compare(params(Api.searchUrl("  a&b=c #1 ", defaults, "", 1, "")).q, "a&b=c #1");
    }
    function test_toplist_range() { // a month of one subject is only a few images
        compare(params(Api.searchUrl("", defaults, "", 1, "")).topRange, "1M");
        compare(params(Api.searchUrl("touhou", defaults, "", 1, "")).topRange, "1y");
    }
    function test_search_url_any_size_and_page() {
        const p = params(Api.searchUrl("x", Object.assign({}, defaults, { atleast: "", sorting: "relevance" }), "", 3, ""));
        compare(p.atleast, undefined);
        compare(p.topRange, undefined);
        compare(p.page, "3");
    }
    function test_random_keeps_its_seed_on_later_pages() {
        const f = Object.assign({}, defaults, { sorting: "random" });
        compare(params(Api.searchUrl("", f, "", 1, "abc123")).seed, undefined);
        compare(params(Api.searchUrl("", f, "", 2, "abc123")).seed, "abc123");
    }
    function test_sketchy_and_nsfw_need_a_key() {
        const f = Object.assign({}, defaults, { purity: "011" });
        compare(params(Api.searchUrl("", f, "", 1, "")).purity, "100");
        compare(params(Api.searchUrl("", f, "key", 1, "")).purity, "011");
        verify(!Api.searchUrl("", f, "secretkey", 1, "").includes("secretkey"), "the key is a header, never in the URL");
    }

    function test_parse() {
        const r = Api.parse(answer([item({})], { seed: "s1" }));
        compare(r.items, [{ wid: "7jmgey", purity: "sfw", category: "general", resolution: "3840x2160", size: 1342922,
            full: "https://w.wallhaven.cc/full/7j/wallhaven-7jmgey.png", thumb: "https://th.wallhaven.cc/lg/7j/7jmgey.jpg" }]);
        compare([r.page, r.lastPage, r.total, r.seed], [1, 39, 919, "s1"]);
    }
    // the id and the URL end up in a file name and a download: anything unexpected is left out
    function test_parse_drops_bad_items_data() {
        return [
            { tag: "id with a path", bad: { id: "../../x" } },
            { tag: "id and file differ", bad: { id: "aaaaaa" } },
            { tag: "other host", bad: { path: "https://evil.example/full/7j/wallhaven-7jmgey.png" } },
            { tag: "host as a prefix", bad: { path: "https://w.wallhaven.cc.evil.example/full/7j/wallhaven-7jmgey.png" } },
            { tag: "plain http", bad: { path: "http://w.wallhaven.cc/full/7j/wallhaven-7jmgey.png" } },
            { tag: "not an image", bad: { path: "https://w.wallhaven.cc/full/7j/wallhaven-7jmgey.sh" } },
            { tag: "thumb from another host", bad: { thumbs: { large: "https://evil.example/x.jpg" } } },
            { tag: "local thumb", bad: { thumbs: { large: "file:///etc/passwd" } } },
            { tag: "no thumbs", bad: { thumbs: null } },
            { tag: "no path", bad: { path: null } }
        ];
    }
    function test_parse_drops_bad_items(d) {
        compare(Api.parse(answer([item(d.bad), item({})])).items.length, 1);
    }
    function test_parse_unreadable_data() {
        return [{ tag: "empty", text: "" }, { tag: "html", text: "<html>" }, { tag: "null", text: "null" },
                { tag: "no data", text: "{}" }, { tag: "data is no list", text: '{"data": 1, "meta": {}}' }, { tag: "no meta", text: '{"data": []}' }];
    }
    function test_parse_unreadable(d) { compare(Api.parse(d.text), null); }

    function test_load_filters_data() {
        return [
            { tag: "empty", text: "" }, { tag: "broken", text: "{" }, { tag: "null", text: "null" }, { tag: "list", text: "[1]" },
            { tag: "bad values", text: '{"categories": "000", "sorting": "rm -rf", "atleast": "1x1", "purity": "222"}' },
            { tag: "wrong types", text: '{"categories": 111, "sorting": [], "atleast": null, "purity": true}' }
        ];
    }
    function test_load_filters(d) { compare(Api.loadFilters(d.text), { categories: "111", sorting: "toplist", atleast: "1920x1080", purity: "100" }); }
    function test_load_filters_keeps_good_values() {
        const f = { categories: "010", sorting: "random", atleast: "", purity: "110" };
        compare(Api.loadFilters(JSON.stringify(Object.assign({ other: 1 }, f))), f);
    }

    function test_toggle() {
        compare(Api.toggle("111", 1), "101");
        compare(Api.toggle("101", 1), "111");
        compare(Api.toggle("010", 1), "010", "the last one stays on");
    }

    function test_files() {
        compare(Api.fileName("https://w.wallhaven.cc/full/7j/wallhaven-7jmgey.png"), "wallhaven-7jmgey.png");
        verify(Api.isFileOf("wallhaven-7jmgey.png", "7jmgey"));
        verify(Api.isFileOf("wallhaven-7jmgey_1920x1080.png", "7jmgey"));
        verify(!Api.isFileOf("wallhaven-7jmgeyx.png", "7jmgey"));
        verify(!Api.isFileOf("other-7jmgey.png", "7jmgey"));
    }

    function test_is_key() {
        verify(Api.isKey("0123456789abcdefABCDEF0123456789"));
        ["", "short", "has space 0123456789abcdef01234567", "line\nbreak0123456789abcdef0123456789", "ünïcode0123456789abcdef01234567"].forEach(k => verify(!Api.isKey(k), k));
    }

    function test_error_text() {
        [0, 401, 429, 500].forEach(s => verify(Api.errorText(s).length > 0));
        verify(Api.errorText(500).includes("500"));
    }
}
