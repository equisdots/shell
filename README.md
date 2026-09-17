# shell

Quickshell shell for the [equisdots](https://github.com/equisdots) desktop,
built up port by port from xlinux (the stable base).

Version: **0.1.0** · License: MIT

## State

The xlinux shell was ported as-is (behaviour preserved, naming updated) and
restructured into `core/` + `ui/`; it is the shell running live at
`~/.config/hypr/scripts/quickshell`. Renames applied: `dock` to `bar`, the
legacy bar to `ClassicBar`; engine values `"bar"`/`"classic"`; config keys
`"bar"`, `"classicbar"`, `"barEngine"` (contract kept).

Running subsystems:

- **Bar** — host + both engines (zones/classic) + 18 modules + editor.
- **Popups** — applauncher, battery, calendar, guide, music, network,
  system-monitor, updater, volume.
- **Panels** — clipboard, davincix, file-search, focustime, idle,
  quickactions, quicknotes, rss-reader, scale, window-controls.
- **Lock**, **notifications** (server + history + popups) and the **floating
  widgets** (faces, redactor, loader).
- **Core** — Config, Caching, Scaler, WindowRegistry.js, Personalization.js,
  EditorNav.js, Theme/SysData/Cava/WidgetSync and the compositor adapter
  (`core/Compositor.qml` + `core/compositors/Hyprland.qml`).

Known pending:

- Compositor scope is Hyprland; the Niri backend in
  `equisdots/docs/compositor-api.md` is a plan item, not active work.
- The palette directory is frozen at `dock/palettes` (shared contract with
  `theme-sync`, `colors.lua` and `dots`).
- Some popup helpers (diary, schedule) have no script yet; schedule is
  optional (existence-guarded), diary is still a dead button.
- The `install/` layer does not exist yet.

## Layout

| Path | Content |
|---|---|
| `Shell.qml` | Entry point (mounts `Main`, `Bar`, `Floating`, `Widgets`) |
| `core/` | Services and contracts (no visuals) |
| `core/compositors/Hyprland.qml` | Hyprland backend of the compositor surface |
| `core/scripts/watchers/` | Data-fetcher scripts the bar polls |
| `ui/bar/` | Bar host, engines, modules, `Colors.qml`, `edit/` + `editor/`, `popups/` |
| `ui/panels/` | Standalone widgets (davincix, clipboard, focustime, ...) |
| `Lock.qml` (root) | PAM session lock (alternate entry point) |
| `ui/notifications/`, `ui/widgets/` | Notification layer, floating widgets |
| `ui/settings/tabs/` | Shared settings tabs (host API) |

## Docs

- `docs/architecture.md` — layer map and contracts.
- `docs/bar.md` — bar host, both engines, zones, styles, classic parity.
- `docs/bar-modules.md` — module contract, `ModulePill` API, compact mode,
  per-module personalization.
- `docs/windows.md` — windows, widget popups, IPC and watchers.
- `docs/desktop-widgets.md` — floating widget subsystem and redactor.
- `docs/themes.md` — palette system, live editing and theme-sync.
- `docs/personalization.md` — configuration surface (bar engines, modules,
  per-subsystem options).
