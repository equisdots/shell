pragma Singleton
// ═══════════════════════════════════════════════════════════════════════════
// shell · core — Compositor
//
// Single entry point to the compositor for the whole UI. Widgets must never
// call hyprctl/niri directly: they consume the command arrays (for their
// pollers) and the action functions exposed here.
//
// The implementation lives in core/compositors/<backend>.qml. Hyprland is the
// current backend; a Niri backend must implement the same surface (commands
// producing the same shapes plus the same actions).
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick
import "compositors"

QtObject {
    id: root

    readonly property var backend: Hyprland {}

    // Data sources for the bar pollers (same output shape as before the port).
    readonly property var workspacesCommand: root.backend.workspacesCommand
    readonly property var keyboardCommand: root.backend.keyboardCommand
    readonly property var focusCommand: root.backend.focusCommand

    // Live actions.
    function setWindowBorderColors(activeHex, inactiveHex) {
        root.backend.setWindowBorderColors(activeHex, inactiveHex);
    }

    function switchWorkspace(name) {
        root.backend.switchWorkspace(name);
    }

    function cycleKeyboardLayout() {
        root.backend.cycleKeyboardLayout();
    }
}
