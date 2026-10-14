import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/WindowRegistry.js" as Registry
import "./bar"

// ═══════════════════════════════════════════════════════════════════════════
// Mascots — equisdots integration for the mascot island/notch module.
//
// The island UI ships as a plugin (Nyx) that declares its overlay through
// `provides.mascots.overlay`; this wrapper resolves it from the plugin
// catalog — managed deploy or a user plugin — and injects the live palette,
// the settings file path, the widget-occlusion hooks, the widget
// list/launcher used by the dock, plus live data (quick-action states, system
// stats, persisted favorites). With no provider installed the wrapper simply
// renders nothing.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    visible: false
    width: 0
    height: 0

    Colors { id: themeColors }

    Caching { id: paths }

    // ── favorites (persisted in settings.json → mascots.dock.favorites) ────
    readonly property var favorites: {
        Config.rev; // re-evaluate whenever settings mutate
        let m = Config.rawSettings.mascots || {};
        let d = m.dock || {};
        return (d.favorites && d.favorites.length !== undefined) ? d.favorites : [];
    }
    function toggleFavorite(id) {
        let m = Object.assign({}, Config.rawSettings.mascots || {});
        let d = Object.assign({}, m.dock || {});
        let f = (d.favorites && d.favorites.length !== undefined) ? d.favorites.slice() : [];
        let i = f.indexOf(String(id));
        if (i >= 0) f.splice(i, 1); else f.push(String(id));
        d.favorites = f;
        m.dock = d;
        Config.setSetting("mascots", m);
    }

    // ── quick-action states (Wi-Fi / Bluetooth / mute), polled ─────────────
    property var qaState: ({ wifi: false, bt: false, mute: false })
    function refreshQuick() { qaProc.running = false; qaProc.running = true; }
    Process {
        id: qaProc
        command: ["bash", "-c",
            "w=$(nmcli -t -f WIFI g 2>/dev/null); " +
            "b=$(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'); " +
            "m=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -c MUTED); " +
            "printf '%s|%s|%s' \"$w\" \"$b\" \"$m\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = this.text.trim().split("|");
                root.qaState = {
                    wifi: p[0] === "enabled",
                    bt: parseInt(p[1]) > 0,
                    mute: parseInt(p[2]) > 0
                };
            }
        }
    }
    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: root.refreshQuick()
    }
    function runQuick(id) {
        const mgr = Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh";
        let args = null;
        if (id === "network") args = ["toggle", "network", "wifi"];
        else if (id === "bluetooth") args = ["toggle", "network", "bt"];
        else if (id === "volume") args = ["toggle", "volume"];
        else if (id === "music") args = ["toggle", "music"];
        if (args) Quickshell.execDetached([mgr].concat(args));
        else Quickshell.execDetached([mgr, "open", String(id)]);
        refreshTimer.restart();
    }
    Timer { id: refreshTimer; interval: 300; onTriggered: root.refreshQuick() }

    readonly property var quickActions: [
        { id: "network",        label: "Wi-Fi",  icon: "󰖩", active: root.qaState.wifi },
        { id: "bluetooth",      label: "BT",     icon: "󰂯", active: root.qaState.bt },
        { id: "volume",         label: "Volume", icon: "󰕾", active: !root.qaState.mute },
        { id: "music",          label: "Music",  icon: "󰝚", active: false },
        { id: "system-monitor", label: "Stats",  icon: "󰨇", active: false }
    ]

    // ── live system stats ──────────────────────────────────────────────────
    readonly property var stats: [
        { id: "cpu",  label: "CPU",  icon: "", value: SysData.cpu + "%",         frac: SysData.cpu / 100 },
        { id: "ram",  label: "RAM",  icon: "", value: SysData.ramPercent + "%",  frac: SysData.ramPercent / 100 },
        { id: "temp", label: "TEMP", icon: "", value: SysData.temp + "°",        frac: Math.min(1, SysData.temp / 100) }
    ]
    Component.onCompleted: SysData.subscribe()
    Component.onDestruction: SysData.unsubscribe()

    // Live wallpaper preview for the Davincix card: davincix repaints
    // current_wallpaper.png whenever the background changes; watching the file
    // bumps wallpaperRev so the dock thumbnail reloads with a fresh URL.
    readonly property string wallpaperPreviewPath: paths.getCacheDir("wallpaper_picker") + "/current_wallpaper.png"
    property int wallpaperRev: 0

    FileView {
        path: root.wallpaperPreviewPath
        watchChanges: true
        blockLoading: true
        onFileChanged: root.wallpaperRev++
    }

    // ── notch cards ("things") ─────────────────────────────────────────────
    // Discovered from the shipped (repo) and user dirs by MascotsCatalog; a
    // user file can add a card or override a shipped one. An entry may carry
    // "exec" (a shell command) instead of opening a shell panel.
    readonly property var notchWidgets: {
        let t = MascotsCatalog.things || [];
        let out = [];
        for (let i = 0; i < t.length; i++) {
            let x = t[i];
            if (!x || x.enabled === false || !x.id) continue;
            let e = { id: String(x.id), label: x.label || String(x.id), icon: x.icon || "" };
            if (x.thumb) e.thumb = x.thumb;
            if (String(x.id) === "wallpaper")
                e.thumb = "file://" + root.wallpaperPreviewPath + "?v=" + root.wallpaperRev;
            out.push(e);
        }
        return out;
    }
    function thingExec(id) {
        let t = MascotsCatalog.things || [];
        for (let i = 0; i < t.length; i++)
            if (t[i] && String(t[i].id) === String(id) && t[i].exec) return String(t[i].exec);
        return "";
    }

    // ── overlay (resolved from the plugin catalog) ─────────────────────────
    readonly property string overlaySource: MascotsCatalog.overlaySource

    function syncOverlay() {
        let src = root.overlaySource;
        if (String(overlayLoader.source) === src) return;
        if (src === "") { overlayLoader.setSource(""); return; }
        overlayLoader.setSource(src, {
            settingsPath: Quickshell.env("HOME") + "/.config/hypr/settings.json",
            widgetStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell/current_widget",
            dockWidgetName: "applauncher",
            widgetRectProvider: function(name, sw, sh, scale) {
                return Registry.getLayout(name, 0, 0, sw, sh, scale);
            },
            quickHandler: function(id) { root.runQuick(id); },
            widgetLauncher: function(id) {
                let exec = root.thingExec(id);
                if (exec !== "") { Quickshell.execDetached(["bash", "-c", exec]); return; }
                Quickshell.execDetached([
                    Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh",
                    "open", String(id)
                ]);
            }
        });
    }
    Component.onCompleted: root.syncOverlay()
    Connections {
        target: MascotsCatalog
        function onOverlaySourceChanged() { root.syncOverlay() }
    }

    Loader {
        id: overlayLoader
        onLoaded: item.favoriteToggled.connect(function(id) { root.toggleFavorite(id) })
    }

    // Live values update through bindings on the loaded overlay.
    Binding { target: overlayLoader.item; property: "palette";       value: themeColors;            when: overlayLoader.item !== null }
    Binding { target: overlayLoader.item; property: "mascotCatalog"; value: MascotsCatalog.mascots; when: overlayLoader.item !== null }
    Binding { target: overlayLoader.item; property: "widgetList";    value: root.notchWidgets;      when: overlayLoader.item !== null }
    Binding { target: overlayLoader.item; property: "quickActions";  value: root.quickActions;      when: overlayLoader.item !== null }
    Binding { target: overlayLoader.item; property: "stats";         value: root.stats;             when: overlayLoader.item !== null }
    Binding { target: overlayLoader.item; property: "favorites";     value: root.favorites;         when: overlayLoader.item !== null }
}
