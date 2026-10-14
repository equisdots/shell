pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
// PluginsCatalog — discovery for the equisdots plugin standard (shell side).
//
// Scans the managed and user plugin dirs through core/scripts/plugins_scan.sh
// and exposes one ordered array:
//
//   plugins  [{ id, name, version, author, description, type, toggle,
//               enabled, settingsTab?, _base, ... }] — one per installed
//            plugin, sorted by name. `enabled` already resolves the effective
//            switch from settings.json (toggle path / defaultEnabled).
//
// User plugins override managed ones on id collisions (scan order: user
// first). Drop a folder with a plugin.json in `~/.config/hypr/plugins-user/`
// and call refresh() (or restart the shell) and it shows up.
//
// The Settings → Plugins page renders this catalog; `rev` bumps after every
// scan so bindings re-evaluate.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: catalog

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/quickshell/core/scripts/plugins_scan.sh"
    readonly property string managed: home + "/.config/hypr/plugins"
    readonly property string userDir: home + "/.config/hypr/plugins-user"
    readonly property string settings: home + "/.config/hypr/settings.json"

    property var plugins: []
    property int rev: 0

    function refresh() { scan.running = false; scan.running = true }

    // ── UI resolution (shared by the shell integrations) ──────────────────
    // Absolute path of a plugin's UI root: managed plugins resolve to the
    // shell-tree deploy (ui/plugins/<id>); user plugins to their own folder.
    // `rel` appends a repo-relative path (settings pages, mascot dirs, ...).
    function uiPath(p, rel) {
        if (!p || !p.id) return "";
        let base = String(p._base || "");
        let userRoot = home + "/.config/hypr/plugins-user/";
        let rootDir = (base.indexOf(userRoot) === 0)
                      ? base
                      : home + "/.config/hypr/scripts/quickshell/ui/plugins/" + p.id;
        if (!rel) return rootDir;
        return rootDir + "/" + String(rel).replace(/^\.\//, "");
    }
    function uiUrl(p, rel) {
        let path = uiPath(p, rel);
        return path === "" ? "" : "file://" + path;
    }

    Process {
        id: scan
        running: true
        clearEnvironment: false
        environment: ({
            PLUGINS_MANAGED: catalog.managed,
            PLUGINS_USER: catalog.userDir,
            PLUGINS_SETTINGS: catalog.settings
        })
        command: ["bash", catalog.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let o = JSON.parse(this.text);
                    catalog.plugins = Array.isArray(o) ? o : [];
                    catalog.rev++;
                } catch (e) {}
            }
        }
    }
}
