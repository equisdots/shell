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
- `timeFormat`: clock format for the zones engine (a `Qt.formatDateTime`
  pattern, e.g. `HH:mm`, `HH:mm:ss`, `h:mm a`); the classic engine keeps its
  own `classicbar.timeFormat`.
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
| `size` | Font pixel size override (0 = module default) |
| `effect` | Per-module view effect: `""` (none) or `"typewriter"` (clock) |
| `cursor` | Blinking cursor for the typewriter effect (`true`/`false`) |

Precedence for the content color: module `color` > `iconColor` > the module's
own logic (accent islands draw content in `colors.base`). For the fill:
module `fill` > zone `fill` > bar-wide settings.

Built-in defaults: `battery`, `settings`, `search`, `time` and `help` ship with
their palette role fill enabled (`fill: "on"`); `"default"` on them returns to
that built-in fill, while `"off"` forces a transparent island. The rest follow
the bar-wide settings unless overridden.

Built-in accents (accent islands that recolor with the palette, like
wifi/bluetooth): `help` peach, `search` sapphire, `settings` mauve,
`update` green, `time` teal, `date` blue, `media` pink, `tray` sapphire,
`keyboard` color5, `wifi` color6, `bluetooth` color4, `sysmon` color1,
`volume` color3, `battery` green (red/green dynamic while low/charging),
`recording` red, `weather` yellow, `focus` peach. `workspaces` keeps its own
palette look (`bgRole` crust + `workspaceActive`). An empty `accent` clears the
default.

The workspaces module also exposes its own options (bar-wide, not per-module):
`workspacesMarker` (`"number" | "dot" | "letter" | "custom"`) and
`workspacesMarkerText` (up to 4 characters, used with `custom`); API:
`setWorkspacesMarker(bar, mode)` / `setWorkspacesMarkerText(bar, ch)`.

The `icon` override applies to every module that renders a single glyph
(fixed or state-driven): `help`, `search`, `settings`, `update`, `keyboard`,
`wifi`, `bluetooth`, `volume`, `battery`, `weather`, `focus` and `recording`.
The override replaces the glyph in all states (for example a fixed wifi glyph
for on/off/ethernet). Components call `mod.glyph("<default>")`; wiring it into
any other module is a one-line change.

Not overridable today (they do not render a single configurable glyph):
`tray` (per-app icons), `sysmon` (cpu + ram glyphs), `media` (album art and
transport controls), `workspaces` (numbers/app icons; use
`workspacesMarker` / `workspacesMarkerText`) and `time` / `date` (text).

## Programmatic API

Pure functions in `bar/BarLayout.js` return a new bar object ready for
`Config.setSetting("bar", ...)`:

- `normalizeFillMode(value)` -> `"default" | "on" | "off"`.
- `setZoneFill(bar, zoneId, mode)` -> block fill.
- `setModuleFill(bar, id, mode)` -> island fill.
- `setModuleIcon(bar, id, glyph)` / `setModuleColor(bar, id, color)` /
  `setModuleAccent(bar, id, role)` -> per-module values.
- `setGlobalIconColor(bar, color)` -> bar-wide icon color.
- `setTimeFormat(bar, fmt)` -> zones-engine clock format.
- `setDateFormat(bar, fmt)` -> zones-engine date format.
- `setModuleSize(bar, id, px)` / `setModuleEffect(bar, id, v)` /
  `setModuleCursor(bar, id, v)` -> per-module view options.

The clock typewriter renders per character and only replays the characters that
change (seconds every second, minutes and hours on their change). The cursor
rests after the text, travels to the character being typed and returns to its
position (typewriter carriage), blinking while idle; `cursor` toggles it.
Enable the effect from the Modules page (clock card) or with
`setModuleEffect(bar, "time", "typewriter")`.
- `moduleConfig(bar, id)` -> effective per-module config (defaults + values).

Note: the zones engine implements this surface today. The classic engine
stores its modules as plain ids, so per-island options there are not available
yet; it keeps using the bar-wide settings.

## Notifications

Section `"notifications"` (consumed by `notifications/NotificationPopups.qml`
through the pure API in `core/Notifications.js`):

| Option | Default | Meaning |
|---|---|---|
| `width` | 350 | Popup width (unscaled) |
| `marginTop` / `marginRight` | 60 / 20 | Distance from the top-right corner |
| `spacing` | 12 | Gap between popups |
| `radius` / `padding` | 14 / 12 | Popup corner radius and inner padding |
| `timeout` | 5000 | Default dismiss time in ms for notifications without their own (0 = never) |
| `maxVisible` | 3 | How many popups stay on screen (0 = no limit) |

API (`core/Notifications.js`): `normalize(raw)`, `layout(raw, scale)`,
`defaultTimeout(raw)`, `maxVisible(raw)`, `setOption(raw, key, value)`.


### Workspaces color slots

`modules.workspaces.colors` overrides the per-state colors (role name or
`#hex`); empty values keep the defaults:

| Slot | Default | Applies to |
|---|---|---|
| `active` | `workspaceActive` (palette role, else `mauve`) | Active workspace fill |
| `activeText` | `crust` | Content on the active workspace |
| `occupied` | `color5` (the palette tone used by the keyboard island) | Occupied workspace fill |
| `empty` | `base` | Empty workspace fill |
| `hover` | `surface1` | Hover fill |
| `marker` | `text` | Marker/icons of occupied workspaces |
| `markerEmpty` | `overlay0` | Marker of empty workspaces |

API: `setModuleColorSlot(bar, id, slot, value)` (empty value removes the
override); the generic `colors` map is normalized by `moduleConfig`.


## Subsystem options (generic API)

Ported subsystems without a dedicated module expose their options through
`core/Personalization.js`, one settings section per subsystem:

`lock`, `battery`, `volume`, `music`, `network`, `calendar`, `updater`, `applauncher`, `system-monitor`, `clipboard`, `focustime`, `quicknotes`, `idle`, `file-search`, `rss-reader`, `scale`, `window-controls`, `widgets`

Each section mirrors the subsystem's defaults (sizes, timeouts, poll rates,
booleans). API: `defaults(section)`, `normalize(section, raw)`,
`value(section, raw, key)`, `setOption(section, raw, key, value)`,
`patch(section, raw, key, value)` (ready for `Config.updateJsonBulk`).

Wiring status: the option tables are defined and documented; components
replace their hardcoded values with `value(...)` reads as they are validated
in the testing phase (one line per option).

## Settings panel (BarEditor)

The panel navigation is data-driven from `core/EditorNav.js`: five collapsible
groups (Shell, Bar, Theme, Behavior, System) with their pages. `GROUPS` defines
the defaults; everything else lives in `settings.editor`:

```json
"editor": {
  "collapsed": { "theme": true },
  "defaultPage": "s_general",
  "order": ["shell", "bar", "theme", "behavior", "system"],
  "hidden": ["d_guide"]
}
```

API: `groups()`, `configure(groups, raw)` (applies order/hidden/collapsed),
`pageIds(groups)`, `findItem(groups, id)`, `patch(raw, key, value)`. The rail
renders the result and persists collapse with `Config.setSetting("editor", ...)`;
engine-specific pages (`engine: "bar" | "classic"`) are filtered per engine.

## Notifications layout

`settings.notifications` (core/Notifications.js): `width`, `maxHeight` (0 = auto),
`marginTop`, `marginRight`, `position` (0 tl, 1 tc, 2 tr, 3 bl, 4 bc, 5 br),
`shadow` (0/1), `shadowBlur`, `shadowOffset`, `spacing`, `radius`, `padding`,
`timeout`, `maxVisible`. `layout(raw, scale)` returns scaled values plus the
anchor booleans (`posTop/Bottom/Left/CenterX/Right`). Controls live in
Settings -> Notifications. Centering anchors only the left side with a computed
margin (anchoring left+right stretches the layer).

## Config reactivity

`Config.setSetting()` mutates `rawSettings` in place, so bindings that must
react to live edits depend on `Config.rev` (bumped on every set). General-tab
scalars (`uiScale`, `workspaceCount`, `appScale`) persist through
`onXChanged` -> debounced `saveAppSettings()` (gated on `dataReady`);
`workspaceCount` triggers the bar reload through `qs -p <shell>/Shell.qml
ipc call topbar queueReload`. The three scales are distinct: UI Scale = shell
only, App scale = global display scale (`scripts/scale-menu.sh`), monitor
scale = Hyprland monitors.
