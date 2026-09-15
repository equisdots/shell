# shell

Compositor-agnostic Quickshell shell for the [equisdots](https://github.com/equisdots)
desktop, built up one panel at a time (Hyprland + Niri as targets).

Version: **0.1.0** · License: MIT

## State

Repo skeleton growing from xlinux (the stable base), port by port. xlinux keeps
working; nothing is removed there.

Ported so far, **as-is** (behaviour preserved, only naming updated):

- **Bar** — complete port of the dock/bar (host + both engines + modules +
  editor). Renames applied: `dock` to `bar`, `SerpBar` to `ClassicBar`,
  `serpbar` to `classicbar`; engine values `"bar"`/`"classic"`; config keys
  `"bar"`, `"classicbar"`, `"barEngine"`. The module catalog/loaders now use
  `bar/modules/` relative paths.
- **Core** — shell services: `Config`, `Caching`, `Scaler`,
  `WindowRegistry.js` (layout math + widget registry) and the **compositor
  adapter**: `core/Compositor.qml` (singleton, public surface) +
  `core/compositors/Hyprland.qml` (backend). The six bar touch points are wired
  through it: workspaces/focus/keyboard data commands, live window border
  colours, workspace switching and keyboard-layout cycling. The Niri backend
  will implement the same surface.
- **davincix panel** — wallpaper picker.

> Nothing is runnable standalone yet: the entry point (`Shell.qml` + widget
> registry mounting) is missing, and several wiring points still reference the
> live xlinux locations. Known pending items: palette directory and desktop
> scripts (`~/.config/hypr/scripts/*`) still point at the xlinux paths; the
> editor's compositor pages (`HyprlandPage`, `InputPage`, `GpuPage`, `IdlePage`,
> `NotificationsPage`) remain Hyprland-specific and will get their own
> per-compositor treatment; `guide/` and the rest of the panels are still to be
> ported; the davincix panel resolves the kernel through `$DAVINCIX_CLI`, with
> the in-repo `../kernel/davincix.sh` fallback not applicable to this layout
> yet.

## Layout

| Path | Content |
|---|---|
| `core/Compositor.qml` | Compositor surface for the UI (singleton) |
| `core/compositors/Hyprland.qml` | Hyprland backend (commands + actions) |
| `core/Config.qml` | Settings/state service (`settings.json`, envs, keybinds) |
| `core/Caching.qml` | Cache/run/state paths |
| `core/Scaler.qml` | UI scale helper |
| `core/WindowRegistry.js` | Layout math + widget registry (future panels map) |
| `bar/Bar.qml` | Bar host: per-screen `PanelWindow`, pollers, geometry, dual engine |
| `bar/ClassicBar.qml` | Classic engine (left/center/right sections + autohide) |
| `bar/Zone.qml` | Zones engine (data-driven `left/center/right`) |
| `bar/ModulePill.qml` | Pill chrome used by every module |
| `bar/BarLayout.js` | Pure layout/model logic (catalog, zones, classic sections, presets) |
| `bar/Colors.qml` | Palette engine (base16 + semantic roles) |
| `bar/modules/` | The 18 bar modules |
| `bar/BarEditor.qml` | Bar editor widget (SUPER+SHIFT+D target) |
| `bar/edit/` | Editor controls (pills, cards, steppers) |
| `bar/editor/` | Editor pages + `persist-hypr.sh` + search overlay |
| `settings/tabs/` | Shared settings tabs (host API) |
| `panels/davincix/` | Wallpaper picker panel |

Future layers (not created yet): `lock/`, `notifications/`, `install/`,
`guide/`.
