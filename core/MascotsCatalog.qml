pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
// MascotsCatalog — discovery for the island/notch integration (mascot species
// + notch cards).
//
// Sources, in precedence order:
//   1. the user dirs (`~/.config/hypr/mascots/species/` | `notch/`) — they win
//      on id collisions;
//   2. every installed plugin that *provides* mascots content. The rule lives
//      with this integration (not in the plugin standard): a plugin declares
//        "provides": { "mascots": { "overlay"?, "species"?, "cards"? } }
//      with paths relative to its UI root. Managed plugins resolve to the
//      shell-tree deploy; user plugins to their own folder.
//
// The scan (core/scripts/mascots_scan.sh) merges the dirs and exposes:
//   mascots  [{ id, label, icon, entry?, builtin?, _base, ... }] — one per
//            species. `entry` (a QML file, resolved against `_base`) marks a
//            custom species; without it the species is a built-in kind.
//   things   [{ id, label, icon, thumb?, exec?, enabled?, _base, ... }] — one
//            per notch card.
//   overlaySource — the first provider's overlay QML (a file:// URL), used by
//                   ui/Mascots.qml to load the island UI.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: catalog

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/quickshell/core/scripts/mascots_scan.sh"
    readonly property string mascotsUser: home + "/.config/hypr/mascots/species"
    readonly property string thingsUser: home + "/.config/hypr/mascots/notch"

    // Provider entries: [{ plugin, rel }] for a `provides.mascots.<key>`.
    function providers(key) {
        PluginsCatalog.rev; // re-evaluate when the plugin catalog updates
        let out = [];
        let list = PluginsCatalog.plugins || [];
        for (let i = 0; i < list.length; i++) {
            let p = list[i] || {};
            let m = (p.provides && typeof p.provides === "object"
                     && p.provides.mascots && typeof p.provides.mascots === "object")
                    ? p.provides.mascots : null;
            if (m && typeof m[key] === "string" && m[key] !== "")
                out.push({ plugin: p, rel: m[key] });
        }
        return out;
    }

    readonly property var speciesDirs: {
        let ps = catalog.providers("species");
        let out = [];
        for (let i = 0; i < ps.length; i++)
            out.push(PluginsCatalog.uiPath(ps[i].plugin, ps[i].rel));
        return out;
    }
    readonly property var cardsDirs: {
        let ps = catalog.providers("cards");
        let out = [];
        for (let i = 0; i < ps.length; i++)
            out.push(PluginsCatalog.uiPath(ps[i].plugin, ps[i].rel));
        return out;
    }
    readonly property string overlaySource: {
        let ps = catalog.providers("overlay");
        return ps.length > 0 ? PluginsCatalog.uiUrl(ps[0].plugin, ps[0].rel) : "";
    }

    property var mascots: []
    property var things: []

    function refresh() { scan.running = false; scan.running = true }

    function orderOf(x) { return (x && x.order !== undefined) ? Number(x.order) : 1000 }
    function sortItems(a) {
        return a.slice().sort(function (x, y) {
            let ox = catalog.orderOf(x), oy = catalog.orderOf(y);
            if (ox !== oy) return ox - oy;
            return String(x.label || x.id || "").localeCompare(String(y.label || y.id || ""));
        });
    }

    // Rescan when the plugin catalog changes: a provider may have appeared,
    // been removed or moved.
    Connections {
        target: PluginsCatalog
        function onRevChanged() { catalog.refresh() }
    }

    Process {
        id: scan
        running: true
        clearEnvironment: false
        environment: ({
            MASCOTS_SHIPPED: catalog.speciesDirs.join(":"),
            MASCOTS_USER: catalog.mascotsUser,
            THINGS_SHIPPED: catalog.cardsDirs.join(":"),
            THINGS_USER: catalog.thingsUser
        })
        command: ["bash", catalog.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let o = JSON.parse(this.text);
                    catalog.mascots = catalog.sortItems(o.mascots || []);
                    catalog.things = catalog.sortItems(o.things || []);
                } catch (e) {}
            }
        }
    }
}
