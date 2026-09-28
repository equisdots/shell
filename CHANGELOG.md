# Changelog

All notable changes to the equisdots shell are documented here.
Dates use YYYY-MM-DD.

## [2026-09-28]

### Added
- **Effects kernel** (`core/scripts/hypr-effects.sh` + `core/HyprEffects.qml`): shared reader/writer for the window-effect knobs used by the Hyprland tab and the Window Controls widget. Partial updates, JSON state as source of truth and live apply through `hyprctl eval`; the Lua overrides are only written on demand (close/Save).
- **Theme > Shadows page**: host-drawn popup/menu shadows with `RectangularShadow` (position, size, morph and fade aware), configured from `settings.json -> shadows` and applied live. Panels may expose `shadowRadius` to match their own corners (the app launcher does).
- **Theme > Glass page**: translucent backgrounds plus compositor backdrop blur for popups, menus and the bar through Hyprland layer rules (`hyprland/config/layers.lua`). `settings.json -> glass` drives the background alpha; cards stay opaque so text remains legible.
- **Palette sections**: the Palette page is grouped under centered `X`, `Custom` and `User` titles, with a shared palette card component. Community palettes live in a subfolder and are resolved through `index.json` (`category` + optional `path`).
- **Window border gradients**: optional two-stop gradient per border (second color + angle) in Style and Hyprland, built on a shared `WindowBordersSection` component; the compositor adapter receives border specs instead of plain hex values.
- **Bar shadows**: island capsules and the optional strip draw their own shadows from the same `shadows` config, with surface padding and an input mask so the padding does not capture clicks.

### Changed
- Effect knobs no longer trigger a configuration reload while dragging: changes preview live, and the Lua overrides are persisted once when the UI closes or Save is pressed.
- Bar thickness now sets the cross-size in both orientations (the vertical floor was removed); the Style stepper lower bound is 24.
- The Hyprland tab description reflects the live apply path (no reload).

### Fixed
- BarEditor and WidgetRedactor first open: `uiScale` is taken synchronously from `Config`, avoiding the wrong first layout that displaced the nav pill and morphed the panel.
- Glass: color parsing no longer mistakes the alpha prefix of `#aarrggbb` for red (all surfaces turned reddish).
