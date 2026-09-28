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
- **Theme > Mascots > Species and Count**: the island can show 1, 2 or 3 mascots (`settings.json -> mascots.count`; the island width adapts to the number) and each one can be `flame` (default little fire, replaces the old unrecognizable chibi blob), `cat`, `dog`, `eyes` (just a pair of manga eyes with a big tracking iris, angry lash, sleepy lids and happy arcs) or `mixed` (cat / dog / eyes). Faces are drawn with `QtQuick.Shapes`: pointy ears with inner ear, forehead stripes, whiskers and pink nose for cats; floppy ears, eye patch, muzzle and tongue-when-happy for dogs. Every mood (angry, surprised, happy, sleepy) shows on the face: ears, eyelids, brows and mouth.
- **Mascots > Position**: the island can be anchored to any of the nine screen positions (`settings.json -> mascots.position`, 3x3 pad in Theme > Mascots); the click dock always unfolds from the island toward the screen centre (upwards when the island sits at the bottom).
- **Mascots island dock**: clicking the island unfolds `ui/mascots/MascotDock.qml`, a rectangular panel with small widget miniatures (3 per page, chevron paging and page dots). Picking a miniature launches that widget through `qs_manager.sh open <id>`. Hovering the island surprises the mascots; only the island and the open dock capture input, the rest of the surface stays click-through.
- **Mascots module**: the overlay now lives in a self-contained `ui/mascots/` module (overlay + one file per species + shared face + dock + vendored metrics) with the palette, settings path and widget hooks injected; `ui/Mascots.qml` is a thin shell wrapper, ready to extract to its own repo.

### Changed
- Effect knobs no longer trigger a configuration reload while dragging: changes preview live, and the Lua overrides are persisted once when the UI closes or Save is pressed.
- Bar thickness now sets the cross-size in both orientations (the vertical floor was removed); the Style stepper lower bound is 24.
- The Hyprland tab description reflects the live apply path (no reload).

### Fixed
- BarEditor and WidgetRedactor first open: `uiScale` is taken synchronously from `Config`, avoiding the wrong first layout that displaced the nav pill and morphed the panel.
- Glass: color parsing no longer mistakes the alpha prefix of `#aarrggbb` for red (all surfaces turned reddish).
- Mascots: the pupils now track the cursor proportionally to the eye size (the old offset was a fixed 2.4 px, barely visible at large sizes and disproportionate at the small ones) and the look direction is smoothed per frame.
- Mascots: the look direction compared screen-space cursor coordinates with window-local mascot coordinates, so the eyes only tracked the right half of the screen; the surface origin is now part of the math (also for the widget-occlusion rect).
- Mascots: `idleTimer` / `moodTimer` were referenced as root properties (`overlay.idleTimer`), which is not how QML ids resolve, so the idle-sleep restart threw on hover and never ran from cursor movement.
- Settings menu (SUPER+SHIFT+D) did not open: a missing comma in the `BarEditor.qml` page map broke the whole component, so switching to it left the previous widget's frame on screen.
- Calendar was unreachable: its `WindowRegistry.js` entry was on the same line as a `//` comment and got swallowed, so `getLayout("calendar")` returned null. `scripts/check.sh` now runs a semantic smoke test over the widget registry, since `node --check` cannot see this class of bug.
