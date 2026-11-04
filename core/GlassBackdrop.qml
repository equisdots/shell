pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================================
// GlassBackdrop — synchronized, shell-free desktop capture for Aurora.
//
// The desktop is captured by glass-capture.sh after Theme.captureFreeze unmaps
// the master window and bar. The capture follows current_wallpaper.png, so a
// wallpaper change produces a fresh desktop frame (windows included) and every
// Aurora surface samples the same revision.
//
// The image is deliberately not live: a live screencopy would capture the
// glass surfaces recursively. Desktop motion is represented by the frame taken
// at the last wallpaper change; the alternative is feedback.
// ============================================================================
Item {
    id: root

    readonly property string cacheRoot: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string wallpaperPath: root.cacheRoot + "/quickshell/wallpaper_picker/current_wallpaper.png"
    readonly property string captureDir: root.cacheRoot + "/quickshell/wallpaper_picker/aurora"
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/glass-capture.sh"

    property int revision: 0
    property bool capturing: false
    property bool pending: false
    property int attempts: 0
    property var captures: ({})

    function safeName(name) {
        return String(name || "default").replace(/[^A-Za-z0-9_-]/g, "_");
    }

    function sourceFor(name) {
        return root.captureDir + "/" + root.safeName(name) + ".png";
    }

    function hasCapture(name) {
        return root.captures[root.safeName(name)] === true;
    }

    function requestCapture() {
        if (!Theme.auroraGlass) return;
        if (root.capturing) { root.pending = true; return; }
        if (root.attempts >= 3) return;

        root.capturing = true;
        Theme.captureFreeze = true;
        captureTimer.restart();
    }

    function finishCapture(ok, names) {
        Theme.captureFreeze = false;
        root.capturing = false;
        root.attempts = ok ? 0 : root.attempts + 1;

        if (ok && names && names.length > 0) {
            let next = ({});
            for (let i = 0; i < names.length; i++) {
                if (names[i]) next[root.safeName(names[i])] = true;
            }
            root.captures = next;
            root.revision++;
        }

        if (root.pending) {
            root.pending = false;
            root.requestCapture();
        }
    }


    Component.onCompleted: {
        if (Theme.auroraGlass) root.requestCapture();
    }

    Connections {
        target: Theme
        function onAuroraGlassChanged() {
            if (Theme.auroraGlass) {
                root.attempts = 0;
                root.requestCapture();
            }
        }
        function onSettingsChanged() {
            if (Theme.auroraGlass && Object.keys(root.captures).length === 0)
                root.requestCapture();
        }
    }

    // Theme loads settings.json asynchronously. The first GlassBackdrop can be
    // created before that read completes, so keep a cheap retry (bounded to
    // three failed attempts) until the initial capture exists.
    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            if (Theme.auroraGlass && !root.capturing && Object.keys(root.captures).length === 0)
                root.requestCapture();
        }
    }

    // davinci/xwww updates this file; glass-sync mirrors direct xwww changes.
    FileView {
        path: root.wallpaperPath
        watchChanges: true
        onFileChanged: if (Theme.auroraGlass) { root.attempts = 0; root.requestCapture(); }
    }

    Timer {
        id: captureTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!captureProcess.running) captureProcess.running = true;
        }
    }

    Process {
        id: captureProcess
        command: ["bash", root.scriptPath]
        running: false
        stdout: StdioCollector { id: captureOutput }
        onExited: (code, status) => {
            const names = String(captureOutput.text || "").split("\n").filter(n => n.trim() !== "");
            root.finishCapture(code === 0 && names.length > 0, names);
        }
    }
}
