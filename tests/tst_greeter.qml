import QtQuick
import QtTest
import "../quickshell/services/GreeterState.js" as State

// Run: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_greeter.qml
TestCase {
    name: "Greeter"

    readonly property string listing: [
        "/s/mango.desktop:Name=Mango",
        "/s/mango.desktop:Exec=mango",
        "/s/mango.desktop:DesktopNames=mango;wlroots",
        "/s/a.desktop:Name=Aaa",
        "/s/a.desktop:Exec=a",
        "/s/a.desktop:Name=Later",
        "/s/h.desktop:Name=Hidden",
        "/s/h.desktop:Exec=h",
        "/s/h.desktop:Hidden=true",
        "/s/x.desktop:Name=NoExec"
    ].join("\n") + "\n"

    function test_users() {
        const passwd = [
            "root:x:0:0::/root:/bin/bash",
            "alice:x:1000:1000:Alice A,,,:/home/alice:/bin/fish",
            "nobody:x:65534:65534::/:/usr/bin/nologin",
            "svc:x:1001:1001::/:/usr/bin/nologin",
            "bob:x:1002:1002::/home/bob:/bin/bash"
        ].join("\n") + "\n";
        compare(State.users(passwd), [{ user: "alice", name: "Alice A" }, { user: "bob", name: "bob" }]);
    }

    function test_sessions() {
        const s = State.sessions(listing);
        compare(s.map(x => x.name), ["Aaa", "Mango"]);
        compare(s[1].file, "mango.desktop");
        compare(s[1].exec, "mango");
        compare(s[1].desktops, "mango;wlroots");
    }

    // a session that is gone (an uninstalled compositor) falls back to Mango
    function test_pick() {
        const s = State.sessions(listing);
        compare(State.pick(s, "a.desktop"), 0);
        compare(State.pick(s, "gone.desktop"), 1);
        compare(State.pick([{ file: "x.desktop" }], ""), 0);
    }

    function test_launch() {
        const r = State.launch({ file: "mango.desktop", name: "Mango", exec: "mango", desktops: "mango;wlroots" });
        compare(r.command, ["/bin/sh", "-c", "mango"]);
        verify(r.environment.indexOf("XDG_CURRENT_DESKTOP=mango:wlroots") >= 0, r.environment);
        verify(r.environment.indexOf("XDG_SESSION_DESKTOP=mango") >= 0, r.environment);
        const bare = State.launch({ file: "a.desktop", name: "A", exec: "a", desktops: "" });
        verify(!bare.environment.some(e => e.startsWith("XDG_CURRENT_DESKTOP=")), bare.environment);
    }
}
