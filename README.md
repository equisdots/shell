# shell

Compositor-agnostic Quickshell shell for the [equisdots](https://github.com/equisdots)
desktop, built up one panel at a time (Hyprland + Niri as targets).

Version: **0.1.0** · License: MIT

## State

Repo skeleton with the **first panel: davincix** (wallpaper picker), ported
as-is from xlinux (the stable base). Per the project rule, xlinux keeps working
and panels are ported progressively.

> The davincix panel is **not runnable standalone yet**: it still depends on
> shell services that will land with `core` — theme (`Colors`), `Caching`,
> `Scaler`, `Config`, the widget registry and the `qs_manager` open/close flow.
> Its only external dependency that is ready today is the wallpaper engine:
> [equisdots/davincix](https://github.com/equisdots/davincix) (CLI kernel,
> resolved by the panel via `$DAVINCIX_CLI` or a sibling `kernel/`).

## Layout

| Path | Content |
|---|---|
| `panels/davincix/` | Wallpaper picker UI (first panel) |
| `panels/davincix/lib/` | Pure helpers (`constants.js`, `color.js`) |
| `panels/davincix/components/` | Views: `grid/`, `filter/`, `ConfirmDialog.qml` |

Future layers (not created yet): `core/`, `bar/`, `lock/`, `notifications/`,
`install/`.
