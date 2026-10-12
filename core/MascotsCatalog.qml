pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
// MascotsCatalog — discovery for the Nyx notch (mascot species + notch cards).
//
// Scans the shipped (repo) and user dirs through core/scripts/mascots_scan.sh
// and exposes two ordered arrays:
//
//   mascots  [{ id, label, icon, entry?, builtin?, _base, ... }] — one per
//            species. `entry` (a QML file, resolved against `_base`) marks a
//            custom species; without it the species is a built-in kind.
//   things   [{ id, label, icon, thumb?, exec?, enabled?, _base, ... }] — one
//            per notch card.
//
// User files override or extend the shipped defaults (scan order: user first).
// Drop a file in `~/.config/hypr/mascots/species/` or `.../notch/` and call
// refresh() (or restart the shell) and it shows up.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: catalog

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/quickshell/core/scripts/mascots_scan.sh"
    readonly property string mascotsShipped: home + "/.config/hypr/scripts/quickshell/ui/nyx/mascots"
    readonly property string mascotsUser: home + "/.config/hypr/mascots/species"
    readonly property string thingsShipped: home + "/.config/hypr/scripts/quickshell/notch"
    readonly property string thingsUser: home + "/.config/hypr/mascots/notch"

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

    Process {
        id: scan
        running: true
        clearEnvironment: false
        environment: ({
            MASCOTS_SHIPPED: catalog.mascotsShipped,
            MASCOTS_USER: catalog.mascotsUser,
            THINGS_SHIPPED: catalog.thingsShipped,
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
