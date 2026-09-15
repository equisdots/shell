// ═══════════════════════════════════════════════════════════════════════════
// shell · core/compositors — Hyprland backend
//
// Hyprland implementation of the Compositor surface. It keeps the exact
// commands and scripts used before the port (workspaces.sh, kb_fetch.sh,
// hyprctl) so behaviour is unchanged.
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick
import Quickshell

QtObject {
    id: backend

    readonly property var workspacesCommand: ["bash", "-c", "~/.config/hypr/scripts/workspaces.sh"]
    readonly property var keyboardCommand: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]

    readonly property var focusCommand: ["bash", "-c",
        "hyprctl activewindow -j 2>/dev/null | jq -r 'if (.class != null and .class != \"\" and .address != null and .address != \"\") then (.class + \"\\n\" + .title) else empty end' 2>/dev/null"]

    // Push the active/inactive window border colours live (hex without '#').
    function setWindowBorderColors(activeHex, inactiveHex) {
        const lua = 'hl.config({ general = { col = { active_border = "rgba(' + activeHex + 'ee)", inactive_border = "rgba(' + inactiveHex + 'aa)" } } })';
        Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + lua + "' 2>/dev/null"]);
    }

    function switchWorkspace(name) {
        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + name]);
    }

    function cycleKeyboardLayout() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
    }
}
