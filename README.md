# shell

Compositor-agnostic Quickshell shell for the [equisdots](https://github.com/equisdots)
desktop, built up one panel at a time (Hyprland + Niri as targets).

Version: **0.1.0** · License: MIT

## State

Repo skeleton growing from xlinux (the stable base), port by port. xlinux keeps
working; nothing is removed there.

Ported so far, **as-is** (behaviour preserved, only naming updated):

- **Bar** — complete port of the dock/bar (host + both engines + modules +
  editor). Renames applied: `dock` → `bar`, `SerpBar` → `ClassicBar`,
  `serpbar` → `classicbar`; engine values `"bar"`/`"classic"`; config keys
  `"bar"`, `"classicbar"`, `"barEngine"`. The module catalog/loaders now use
  `bar/modules/` relative paths.
- **davincix panel** — wallpaper picker.

> Nothing is runnable standalone yet: the shell host is missing `core`
> (theme/paths/scaler/config/`WindowRegistry`), the compositor adapter and the
> entry point (`Shell.qml` + registry). Pending wiring is marked in the code
> where relevant (e.g. palette dir and the desktop scripts in `~/.config/hypr`,
> which still point at the live xlinux locations).

## Layout

| Path | Content |
|---|---|
| `bar/Bar.qml` | Bar host: per-screen `PanelWindow`, pollers, geometry, dual engine |
| `bar/ClassicBar.qml` | Classic engine (left/center/right sections + autohide) |
| `bar/Zone.qml` | Zones engine (data-driven `left/center/right`) |
| `bar/ModulePill.qml` | Pill chrome used by every module |
| `bar/BarLayout.js` | Pure layout/model logic (catalog, zones, classic sections, presets) |
| `bar/Colors.qml` | Palette engine (base16 + semantic roles) |
| `bar/modules/` | The 18 bar modules |
| `bar/BarEditor.qml` | Bar editor widget (SUPER+SHIFT+D target) |
| `bar/edit/` | Editor controls (pills, cards, steppers…) |
| `bar/editor/` | Editor pages + `persist-hypr.sh` + search overlay |
| `settings/tabs/` | Shared settings tabs (host API) |
| `panels/davincix/` | Wallpaper picker panel |

Future layers (not created yet): `core/`, `lock/`, `notifications/`,
`install/`, `guide/`.
