# Architecture

## Layers

```
Shell.qml                  entry (imports ./ui, ./ui/bar, ./ui/widgets)
Lock.qml                   alternate entry: PAM session lock (WlSessionLock,
                           launched by lock.sh; imports core/ + ui/bar)
├── core/                  services and contracts (no visuals)
│   ├── Config.qml         settings.json (rawSettings + setSetting/updateJsonBulk)
│   ├── Caching.qml        paths: cacheDir, stateDir, runDir, getCacheDir/getRunDir
│   ├── Scaler.qml         scale helper
│   ├── Compositor.qml     compositor abstraction (compositors/Hyprland.qml)
│   ├── WindowRegistry.js  widget layout registry + positionLayout()
│   ├── Notifications.js   notification options API
│   ├── Personalization.js option tables for every subsystem
│   ├── EditorNav.js       Settings panel groups/pages model
│   ├── Theme.qml / SysData.qml / Cava.qml / WidgetSync.qml
│   └── scripts/watchers/  data_fetchers (executable, feed the bar)
└── ui/                    everything visible
    ├── Main.qml           master window: widget stack + morph + IPC handler
    ├── Floating.qml       floating widget host
    ├── ScreenshotOverlay.qml
    ├── bar/               Bar.qml (host), ClassicBar.qml, ModulePill, Zone,
    │   │                  Colors.qml, BarLayout.js (engines API)
    │   ├── modules/       18 bar modules
    │   ├── editor/        BarEditor pages (lazy Loaders in BarEditor.qml)
    │   ├── edit/          editor controls (FieldCard, ToggleCard, ...)
    │   └── popups/        applauncher, battery, guide, music, network,
    │                      system-monitor, updater, volume (bar-triggered)
    ├── timex/             timex subsystem UI: TimexPopup (clock + calendar +
    │                      hourly forecast + day panel) and TimexTab (settings;
    │                      sources live in the equisdots/timex repo)
    ├── panels/            clipboard, davincix, file-search, focustime, idle,
    │                      quickactions, quicknotes, rss-reader, scale,
    │                      window-controls
    ├── notifications/     NotificationPopups
    ├── settings/tabs/     shared tabs (General, Keybind, Monitors, Startup,
    │                      Weather) with the `host` contract
    └── widgets/           floating widget system (faces, redactor, loader)
```

## Contracts

- **Shell call chain**: `SUPER+SHIFT+D` → `qs_manager.sh` → `qs ipc call main
  handleCommand "toggle <widget>"` → `ui/Main.qml` → `getLayout()` →
  `WindowRegistry.getLayout()` + `positionLayout()` → `StackView.replace`.
  Component URLs are resolved with `Qt.resolvedUrl("../" + comp)` from `ui/`.
- **Settings**: `Config.rawSettings` is the single source; panel writes with
  `Config.setSetting(key, value)` (top-level keys: `dock`, `classicbar`,
  `barEngine`, `editor`, `widgets`, `notifications`, ...). `setSetting` mutates
  in place: bindings that must react are refreshed imperatively.
- **Widget positions**: `settings.widgets.<id>.position` overrides the registry
  layout (`default` = widget's own layout; 8 anchors with a 20px scaled margin).
- **Bar engines**: `BarLayout.js` owns both engines (`bar`, `classic`),
  module fills/accents/icons, zone layouts and the `ENGINES` catalog.
- **Personalization**: `Personalization.js` exposes one option table per
  subsystem (`lock`, `battery`, `volume`, ... , `widgets`) with
  `defaults/normalize/value/setOption/patch`.
- **Panel navigation**: `EditorNav.js` (collapsible groups); the rail is
  data-driven and collapse state persists in `settings.editor`.

## Runtime rules

- Copied scripts must keep the executable bit (`chmod +x`): QML `Process`
  runs them directly.
- Glyphs must exist in `Hack Nerd Font` — verify with
  `fc-list :charset=<cp> family` before adding an icon.
- UI colors always come from palette roles through a local `Colors` instance;
  scaling through `bar.s()` / `LayoutMath.s()`.
