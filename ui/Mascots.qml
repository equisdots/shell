import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
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

    Caching { id: paths }

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

    MascotsOverlay {
        palette: themeColors
        settingsPath: Quickshell.env("HOME") + "/.config/hypr/settings.json"
        widgetStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell/current_widget"
        dockWidgetName: "applauncher"
        widgetRectProvider: function(name, sw, sh, scale) {
            return Registry.getLayout(name, 0, 0, sw, sh, scale);
        }
        widgetList: [
            { id: "calendar",       label: "Timex",     icon: "󰅐" },
            { id: "wallpaper",      label: "Davincix",  icon: "󰥶",
              thumb: "file://" + root.wallpaperPreviewPath + "?v=" + root.wallpaperRev },
            { id: "applauncher",    label: "Launcher",  icon: "󰀻" },
            { id: "clipboard",      label: "Clipboard", icon: "󰨸" },
            { id: "idle",           label: "Idle",      icon: "󰤄" },
            { id: "focustime",      label: "Focus",     icon: "󰔛" },
            { id: "updater",        label: "Updater",   icon: "󰇚" },
            { id: "system-monitor", label: "Monitor",   icon: "󰨇" },
            { id: "quicknotes",     label: "Notes",     icon: "󱇗" },
            { id: "rss-reader",     label: "RSS",       icon: "󰑫" },
            { id: "file-search",    label: "Files",     icon: "󰮗" },
            { id: "music",          label: "Music",     icon: "󰝚" },
            { id: "network",        label: "Network",   icon: "󰖩" },
            { id: "volume",         label: "Volume",    icon: "󰕾" },
            { id: "battery",        label: "Battery",   icon: "󰁹" },
            { id: "palette",        label: "Palettes",  icon: "󰏘" },
            { id: "bar-editor",     label: "Settings",  icon: "󰒓" },
            { id: "widgets-redactor", label: "Widgets", icon: "󱇙" }
        ]
        quickActions: [
            { id: "network",        label: "Wi-Fi",   icon: "󰖩" },
            { id: "bluetooth",      label: "Bluetooth", icon: "󰂯" },
            { id: "volume",         label: "Volume",  icon: "󰕾" },
            { id: "music",          label: "Music",   icon: "󰝚" },
            { id: "system-monitor", label: "Stats",   icon: "󰨇" }
        ]
        widgetLauncher: function(id) {
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh",
                "open", String(id)
            ]);
        }
    }
}
