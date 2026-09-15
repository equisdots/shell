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
- `iconColor`: default content color for every module (a `colors.*` role name
  or a `#hex` string; empty = per-module defaults).
- `roundness`, `thickness`, `edgeGap`, `position`, `palette`, `font`,
  `barOpacity`.
- Per zone: `unify` (single pill for the whole zone), `zoneBg` (optional
  container role), `borderWidth`, `borderColor`.

## Module customization

Per-module values live in the bar config under `modules`, keyed by module id.
Every field is optional:

```json
"bar": {
  "iconColor": "",
  "modules": {
    "search": { "icon": "\uf0349", "color": "#89b4fa", "fill": "on", "accent": "" }
  }
}
```

| Field | Meaning |
|---|---|
| `icon` | Glyph override for modules that support it (see below) |
| `color` | Content color: a `colors.*` role name or a `#hex` string |
| `fill` | Island fill: `"default"` / `"on"` / `"off"` (booleans accepted) |
| `accent` | Accent role override (e.g. `"green"`), turning the island into an accent island like wifi/bluetooth |

Precedence for the content color: module `color` > `iconColor` > the module's
own logic (accent islands draw content in `colors.base`). For the fill:
module `fill` > zone `fill` > bar-wide settings.

The `icon` override applies to modules with a fixed glyph, which call
`mod.glyph("<default>")` in their component: `help`, `search`, `settings`,
`update` and `keyboard` today. Modules whose icon changes with state (wifi,
battery, volume, ...) keep their state icons; wiring `glyph()` into any other
module is a one-line change.

## Programmatic API

Pure functions in `bar/BarLayout.js` return a new bar object ready for
`Config.setSetting("bar", ...)`:

- `normalizeFillMode(value)` -> `"default" | "on" | "off"`.
- `setZoneFill(bar, zoneId, mode)` -> block fill.
- `setModuleFill(bar, id, mode)` -> island fill.
- `setModuleIcon(bar, id, glyph)` / `setModuleColor(bar, id, color)` /
  `setModuleAccent(bar, id, role)` -> per-module values.
- `setGlobalIconColor(bar, color)` -> bar-wide icon color.
- `moduleConfig(bar, id)` -> effective per-module config (defaults + values).

Note: the zones engine implements this surface today. The classic engine
stores its modules as plain ids, so per-island options there are not available
yet; it keeps using the bar-wide settings.
