import QtQuick
import Quickshell
import "../core/WindowRegistry.js" as Registry
import "./bar"
import "./mascots"

// ═══════════════════════════════════════════════════════════════════════════
// Mascots — equisdots integration for the standalone mascots module.
//
// The module lives in ui/mascots/ (MascotsOverlay + one file per species +
// MascotFaceEyes + MascotDock) and never imports the shell: this thin wrapper
// injects the live palette, the settings file path, the widget-occlusion hooks
// and the widget list/launcher used by the click dock. Moving the module to
// its own repo means dropping ui/mascots/ and reimplementing this wrapper
// there (pass any palette/settings/widgets source you like).
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    visible: false
    width: 0
    height: 0

    Colors { id: themeColors }

    MascotsOverlay {
        palette: themeColors
        settingsPath: Quickshell.env("HOME") + "/.config/hypr/settings.json"
        widgetStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell/current_widget"
        dockWidgetName: "applauncher"
        widgetRectProvider: function(name, sw, sh, scale) {
            return Registry.getLayout(name, 0, 0, sw, sh, scale);
        }
        widgetList: [
            { id: "calendar",       label: "Timex",     icon: "\uf0e17" },
            { id: "wallpaper",      label: "Davincix",  icon: "\uf0976" },
            { id: "applauncher",    label: "Launcher",  icon: "\uf003b" },
            { id: "clipboard",      label: "Clipboard", icon: "\uf0a38" },
            { id: "idle",           label: "Idle",      icon: "\uf0150" },
            { id: "focustime",      label: "Focus",     icon: "\uf051b" },
            { id: "updater",        label: "Updater",   icon: "\uf01da" },
            { id: "system-monitor", label: "Monitor",   icon: "\uf0a07" },
            { id: "quicknotes",     label: "Notes",     icon: "\uf11d7" },
            { id: "rss-reader",     label: "RSS",       icon: "\uf046b" },
            { id: "file-search",    label: "Files",     icon: "\uf0b97" },
            { id: "music",          label: "Music",     icon: "\uf075a" },
            { id: "network",        label: "Network",   icon: "\uf05a9" },
            { id: "volume",         label: "Volume",    icon: "\uf057e" },
            { id: "battery",        label: "Battery",   icon: "\uf0079" },
            { id: "bar-editor",     label: "Settings",  icon: "\uf0493" },
            { id: "widgets-redactor", label: "Widgets", icon: "\uf11d9" }
        ]
        widgetLauncher: function(id) {
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh",
                "open", String(id)
            ]);
        }
    }
}
