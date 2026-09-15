# Personalization API

Everything the shell exposes for customization lives in `settings.json`,
served by the core `Config` service and consumed live by the UI. This document
is the reference for that surface; new options are documented here as they
land. The current focus is the bar.

## Bar engines

| Key | Values | Meaning |
|---|---|---|
| `barEngine` | `"bar"` / `"classic"` | Zones engine / classic sections engine |
| `bar` | object | Zones engine settings |
| `classicbar` | object | Classic engine settings |

Shared, bar-wide controls (see `bar/BarLayout.js` for defaults and presets):

- `stylePreset`: `"modular"` (independent islands), `"solid"` (continuous
  strip, islands float) or `"fill"` (strip touches the screen edge).
- `pillBg` / `pillSolid` / `barBg`: island fill switch, solid vs translucent
  fill, and continuous bar strip.
- `roundness`, `thickness`, `edgeGap`, `position`, `palette`, `font`,
  `barOpacity`.
- Per zone: `unify` (single pill for the whole zone), `zoneBg` (optional
  container role), `borderWidth`, `borderColor`.

## Island fill (per island and per block)

Each island can force its fill independently of the bar-wide settings, and a
whole block (zone) can set the default for its islands.

- `bar.zones[].fill` - block default: `"default"` | `"on"` | `"off"`.
- `bar.zones[].modules[].fill` - island override with the same values.
- Booleans are accepted for convenience: `true` = `"on"`, `false` = `"off"`.
- A missing value means `"default"`.

Resolution order for one island:

1. Island value (`modules[].fill`).
2. Block value (`zones[].fill`).
3. Bar-wide settings (`pillBg`, `barBg`, `pillSolid`, `unify`).

Meaning of the values:

- `"on"`: force the pill fill even when the bar-wide defaults would render it
  transparent (useful for islands like media/tray, or under a `solid`/`fill`
  style). Accent islands keep their accent fill.
- `"off"`: force a transparent island (useful to blend selected icons into the
  zone container).
- `"default"`: inherit the behavior described above.

Programmatic helpers (pure functions, return a new bar object ready for
`Config.setSetting("bar", ...)`) live in `bar/BarLayout.js`:

- `normalizeFillMode(value)` -> canonical `"default" | "on" | "off"`.
- `moduleFillMode(zone, id)` -> effective mode for an island.
- `setModuleFill(bar, zoneId, id, mode)` -> sets one island.
- `setZoneFill(bar, zoneId, mode)` -> sets one block.

Note: the per-island API applies to the zones engine. The classic engine
stores its modules as plain ids, so per-island fill there is not available yet;
its block-level behavior keeps using the bar-wide settings.
