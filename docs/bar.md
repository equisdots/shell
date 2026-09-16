# Bar System — Architecture & Customization

The bar is the shell's position-agnostic bar window: `ui/bar/Bar.qml` hosts **two
interchangeable engines** on any screen edge (`top` / `bottom` / `left` /
`right`) and switches between them live through `settings.json → barEngine`:

- **`bar`** (zones engine, default) — islands grouped into data-driven zones
  (`start` / `center` / `end`) with module drag & drop and per-zone backgrounds.
- **`classic`** (`ui/bar/ClassicBar.qml`) — left/center/right sections, autohide,
  distinct pills and fill styles (classic bar geometry).

Both engines share the palette, the 18 modules and the Bar Editor. Every key
below lives under the top-level `bar` object unless stated otherwise.

---

## 1. File layout

```
shell/
  Shell.qml                  entry point (mounts Main, Bar, Floating, Widgets)
  core/                      services + contracts (Config, Caching, Scaler,
                             WindowRegistry.js, Theme, SysData, Cava, WidgetSync,
                             Compositor + compositors/, scripts/watchers/)
  ui/bar/
    Bar.qml                  host PanelWindow: geometry, pollers, IPC, engines
    Zone.qml                 renders ONE zone as a Row (horizontal) / Column
    ClassicBar.qml           classic engine renderer
    ModulePill.qml           shared island pill (all visual plumbing)
    Colors.qml               palette loader + semantic role derivation
    BarLayout.js             pure-JS engine: zones, catalog, migration, classic
    modules/*.qml            the 18 modules
    edit/                    editor controls (FieldCard, ToggleCard, steppers…)
    editor/                  editor pages + SearchOverlay + persist-hypr.sh
    popups/                  popups triggered by bar modules
```

The palettes themselves (**frozen shared path**) live at
`~/.config/hypr/scripts/quickshell/dock/palettes/`, deployed from the
`equisdots/palettes` repo (also read by `theme-sync` and `colors.lua`).

---

## 2. Data flow

```
settings.json
   "barEngine": "bar" | "classic"
   "bar": { position, palette, thickness, zones: [...] }
   "classicbar": { position, style, modules: {left, center, right} }
        |
        v
Bar.qml (settingsReader, directory watcher)
   barConfig = BarLayout.getBar(parsed)              // "bar" key
   classicConfig = BarLayout.getClassicbar(parsed)   // "classicbar" key
        |
        v
zones engine:  Bar.qml -> Repeater -> Zone.qml -> module Loaders
classic engine: Bar.qml -> ClassicBar.qml -> section items/groups
        ^                                        |
        |-- shared state: bar.* (pollers/watchers) + colors.* (palette)
```

- **The zones config lives under `"bar"`** (pre-0.2 `"dock"`/`"topbar"` configs
  are migrated once by `BarLayout.getBar()`, the single migration entry point).
  The host watches the `~/.config/hypr` **directory** (atomic tmp+`mv` writes
  kill file watches) with content-compare choke points, so live editing is
  reliable while the shell runs.
- **Data state** (workspaces, wifi, volume, battery, music, clock, sysmon…)
  is fetched by `Process` watchers declared in `Bar.qml` and exposed on the
  `bar` object injected into every module.
- **Colors** always come from `ui/bar/Colors.qml` (palette system), never from
  Matugen.

---

## 3. `settings.json` → `bar` schema

Everything the editor edits lives under one key (defaults from
`BarLayout.defaultBar()`):

```jsonc
{
  "barEngine": "bar",               // "bar" (zones) | "classic"
  "bar": {
    "position": "top",              // "top" | "bottom" | "left" | "right"
    "palette": "x",                 // slug of dock/palettes/<slug>.json
    "thickness": 48,                // bar height (horizontal) or width (vertical)
    "edgeGap": 8,                   // distance from the chosen screen edge
    "roundness": 1.0,               // 0.0 (square) … 1.0 (fully rounded)
    "pillBg": true,                 // islands show a background fill
    "pillSolid": false,             // opaque fill vs semi-transparent
    "barBg": false,                 // continuous strip behind the whole bar
    "barOpacity": 0.85,             // alpha of the barBg strip (0.2–1.0)
    "dragModules": true,            // live island drag & drop on the bar
    "stylePreset": "modular",       // "modular" | "solid" | "fill" (label)
    "borderWidth": 0,               // default border for all zones
    "borderColor": "surface1",      // color role (colors.*) for the border
    "borderFollowPalette": true,    // window borders follow the palette (see themes.md)
    "borderActive": "",             // manual override when the flag is false
    "borderInactive": "",
    "font": "Hack Nerd Font",
    "timeFormat": "HH:mm:ss",       // Qt.formatDateTime pattern (clock)
    "dateFormat": "dddd, MMMM dd",
    "workspacesMarker": "number",   // "number" | "dot" | "letter" | "custom"
    "workspacesMarkerText": "",     // glyph for marker "custom" (≤ 4 chars)
    "modules": {                    // per-module personalization (see bar-modules.md)
      "time": { "effect": "typewriter", "cursor": true }
    },
    "zones": [                      // ← zones are DATA, not code
      {
        "id": "start",              // unique, user-renamable
        "align": "start",           // "start" | "center" | "end"
        "unify": false,             // merge every module into one continuous pill
        "zoneBg": "",               // optional container role ("" = off)
        "zoneBgSolid": false,       // container opaque vs translucent
        "borderWidth": 0,           // per-zone override
        "borderColor": "surface1",
        "modules": [                // ordered; { id, enabled }
          { "id": "help", "enabled": true },
          { "id": "time", "enabled": true }
        ]
      }
      // …add as many zones as you like
    ]
  }
}
```

Notes:

- `stylePreset` is **informative + an apply shortcut**: it only records which
  one-click preset ran last; it never overrides manual tweaks.
- New islands (`weather`, `focus`) ship **disabled** and are re-added disabled
  after updates, so upgrades never change a user's layout on their own.
- **Legacy migration:** if `bar` is missing, `BarLayout.getBar()` first tries
  the pre-0.2 `dock` object, then the old `topbar` key
  (`{left, center, right}` + `topbar*` keys, via `migrateFromTopbar()`).
  Unknown zone/module ids are dropped; missing catalog modules are re-added by
  `normalizeBar()`.

### Editor integration map (Bar group)

| UI page (`core/EditorNav.js`) | settings.json keys                | consumed by                  |
| ----------------------------- | --------------------------------- | ---------------------------- |
| Engine (`d_engine`)           | `barEngine`                       | `Bar.qml` (engine switch)    |
| Position (`d_position`)       | `bar.position`                    | `Bar.qml` geometry           |
| Style (`d_style`)             | `bar.pillBg/pillSolid/barBg/…`    | `Bar.qml` → modules          |
| Zones (`d_zones`)             | `bar.zones`                       | `BarLayout.js` CRUD + `Zone.qml` |
| Classic Bar (`d_classic`)     | `classicbar.*`                    | `ClassicBar.qml`             |
| Modules (`d_modules`)         | `bar.modules.<id>.*`              | modules read `bar.moduleConfig` |
| Workspaces (`d_workspaces`)   | `bar.workspacesMarker*`           | `WorkspacesModule.qml`       |
| Palette (`d_palette`, Theme)  | `bar.palette`, `bar.border*`      | `Colors.qml`, `colors.lua`   |

---

## 4. `BarLayout.js` — the pure engine

All zone/module manipulation is **pure JS** (no QML), so the editor and the bar
share the exact same logic. Key functions:

| function | purpose |
| --- | --- |
| `getBar(raw)` / `normalizeBar(raw)` / `defaultBar()` | parse + normalize + migrate legacy → complete bar config |
| `migrateFromTopbar(raw)` | legacy `topbar` → zones |
| `getModule(id)` / `MODULES` | module catalog (18 entries: id/label/icon/component) |
| `zoneModel(zone)` | enabled module ids of a zone (for Repeaters) |
| `cloneBar / setEnabled / toggleEnabled / isEnabled` | module enable/disable |
| `moduleMove(bar, id, delta)` | reorder, hops zones at edges |
| `moduleMoveTo(bar, id, zoneId, index)` | move to a zone/position (enabled-index semantics) |
| `applyStylePreset(bar, preset)` | one-click bar look (modular/solid/fill, §7) |
| `arrangeAllInZone(bar, align)` / `firstZoneWithAlign` | gather every enabled module into one alignment zone |
| `addZone / removeZone / renameZone / setZoneAlign` | zone CRUD for the editor |
| `setZoneUnify / setZoneBg / setZoneBgSolid / setZoneBorder / setZoneFill` | per-zone visuals |
| `setTimeFormat / setDateFormat` | clock/date formats in the bar config |
| `setWorkspacesMarker / setWorkspacesMarkerText` | empty-workspace markers |
| `moduleConfig / setModuleValue / setModuleIcon / setModuleColor / setModuleFill / setModuleAccent / setModuleSize / setModuleEffect / setModuleCursor / setModuleColorSlot / setGlobalIconColor` | per-module personalization (see bar-modules.md) |
| `flatten(bar)` | flat list for the editor's module list |
| `engines() / engineCapabilityList(e)` | engine catalog for the Engine page |
| `classicTokenModules(id)` | classic layout tokens (`center`, `centerbox` → time+weather) |
| `classicbarDefaults / normalizeClassicbar / getClassicbar` | classic engine config |
| `barToClassicModules(bar)` | seed classicbar modules from the zone config |
| `classicStyleFlags / isFillStyle / classicSectionNames` | classic style vocabulary |

> **Gotcha:** arrays that cross the QML ↔ JS boundary through `property var`
> become `QVariantList`, which breaks `Array.isArray`. All iteration uses the
> length-based `isList()` helper. Keep it that way in new code.

---

## 5. Zone containers & empty-workspace markers

Every zone can render an optional **container background** behind its islands
("capsule inside a capsule") without unifying them:

- `bar.zones[i].zoneBg` — a `colors.*` role name (e.g. `surface0`, `mauve`,
  `crust`). `""` (default) = off. Rendered as a translucent rounded panel that
  hugs the zone's islands; islands keep their own fills on top.
- `bar.zones[i].zoneBgSolid` — `true` makes the container opaque (default
  `false` = translucent).
- Not drawn while the zone is `unify` (unify already provides the background).
- Pure helpers: `BarLayout.setZoneBg(bar, zoneId, role)` /
  `setZoneBgSolid(bar, zoneId, solid)`. Editor: Zones card → per-zone
  **Container bg** + role cycle + **Solid** toggle.

Empty-workspace markers (global, both engines via `WorkspacesModule`):

- `bar.workspacesMarker` — `"number"` (default) | `"dot"` | `"letter"`
  (A, B, C…) | `"custom"`.
- `bar.workspacesMarkerText` — the character shown when marker is `"custom"`
  (up to 4 chars — any Unicode glyph).
- Only EMPTY workspaces use the marker; occupied workspaces show app icons.
  Editor: Workspaces card (visible in both engines).

## 6. Adding / removing / customizing modules

See **`docs/bar-modules.md`** for the module contract, the `ModulePill` API and
the orientation/compact behavior.

Two bar-level settings are consumed by the host (`ui/bar/Bar.qml`):

- `bar.dragModules` (default `true`) — enables drag & drop island reordering
  directly on the bar.
- `bar.barOpacity` (0.2–1, default 0.85) — alpha of the full-bar background
  strip shown when `bar.barBg` is enabled.

### Drag & drop islands

Grab any enabled island with the left mouse button and drag it along the bar:
the remaining islands reorder live under the cursor. Release over a zone to
commit (the new `bar.zones` order is written to `settings.json` atomically);
release **outside** the bar to cancel. A short press without movement still
triggers the module's click.

Implementation notes (for maintainers):

- Pure engine functions live in `BarLayout.js` (`moduleMoveTo`, `enabledCount`,
  `enabledIndexOf`) — they clone, never mutate.
- Each module slot in `ui/bar/Zone.qml` carries a drag `MouseArea`; once the
  ~12 px threshold is crossed it calls `bar.startDrag(id)` and feeds pointer
  positions to `bar.updateDragAt()` / `bar.endDragAt()` / `bar.cancelDrag()`.
- While `bar.dragBusy`, entrance animations and pill size/opacity behaviors are
  suppressed (`ModulePill.dragSuppress`) so model rewrites stay flicker-free.

---

## 7. Bar styles & quick layout

The editor ships three **style presets** (Style card) implemented in
`BarLayout.STYLE_PRESETS` (`applyStylePreset()` touches exactly the keys its
preset declares):

| Preset  | Writes                                      | Look |
| ------- | ------------------------------------------- | ---- |
| Modular | `pillBg:true, pillSolid:false, barBg:false` | floating islands on the raw desktop |
| Solid   | `barBg:true, pillBg:true`                   | continuous strip with islands floating inside |
| Fill    | `barBg:true, pillBg:true, edgeGap:0`        | edge-to-edge strip, no gap to the screen edge |

### Quick layout: "Center all" (Zones card)

The **Center all** pill gathers every **enabled** island into the first zone
aligned `center` (creating it when missing), in catalog order, and never
touches disabled entries — `BarLayout.arrangeAllInZone(bar, align)`.

### Dragging modules inside the editor

Each module chip in the Zones cards is draggable past a ~10 px threshold (short
presses toggle; the ◀ ▶ buttons still work). A ghost follows the pointer, the
target card highlights and an insertion bar shows the spot; drop to move.
Drop indices count **enabled** chips only and ignore the dragged chip — exactly
what `BarLayout.moduleMoveTo()` expects. Same-spot drops are no-ops.

### Hot orientation (no shell reload)

Changing the position/orientation never reloads the shell: an axis flip
(horizontal ↔ vertical) triggers an **in-process remount** — `Bar.qml` empties
the zones model and refills it on the next event turn, recreating every `Zone`
and module `Loader` against the new geometry. Same-axis moves and visual
changes never rebuild anything.

---

## 8. Dual engines (`bar` ⇄ `classic`)

The host supports two interchangeable render engines, switched live (no reload)
through `barEngine` (the zone config under `bar` is preserved and restored):

```jsonc
{
  "barEngine": "classic",           // "bar" | "classic"
  "classicbar": {
    "position": "top",              // "top" | "bottom" | "left" | "right"
    "style": "modular",             // "modular" | "solid" | "fill"
    "widthPercent": 100,            // 40–100: strip length on the main axis
    "distinctPills": false,         // solid/fill: every module/group gets its
                                    // own slab on the strip (default false)
    "thickness": 40,                // px 24–120 or null = inherit bar.thickness
    "opacity": 100,                 // % 20–100 strip alpha (default 100)
    "roundness": 0.6,               // island/strip/group radius knob (0..1)
    "autohide": false,              // slide away + 4px edge tab
    "autohideTimeout": 800,         // ms before hiding after the cursor leaves
    "timeFormat": "HH:mm:ss",       // clock island format (classic engine)
    "modules": {
      "left":   ["help", "search", "settings", "media"],
      "center": [["time", "date", "weather"]],
      "right":  [["keyboard", "wifi", "bluetooth", "volume", "battery"], "tray", "update"]
    }
  }
}
```

- The classic config lives at the top level of `settings.json` next to `bar`;
  the pure section is handled by `BarLayout.js` (`classicbarDefaults`,
  `normalizeClassicbar`, `getClassicbar`, `classicTokenModules`,
  `classicStyleFlags`, `isFillStyle`, `classicSectionNames`,
  `barToClassicModules`).
- **The `bar` zone config is never touched** while the classic engine is active
  and is restored exactly when switching back (`barToClassicModules()` is only
  used to seed a fresh classic config).
- **Size language:** the strip takes `classicbar.thickness` when set (`null` =
  the current `bar.thickness`); radii scale with `classicbar.roundness`; the
  palette is shared (`bar.palette`).
- No module changes: ClassicBar instantiates the **same
  `ui/bar/modules/*.qml` islands** with the standard contract (`bar`, `colors`,
  `zoneReady`, `slotIndex`, `effectiveBorderWidth/Color`, `unified`).

### Sections, tokens and groups

`classicbar.modules` has three sections: **left**, **center**, **right** (main
axis: start / center / end). Each entry is:

- a **module id** (`"time"`) → one loose island;
- a **layout token** (`"center"`, `"centerbox"`) → expands to the loose
  `time` + `weather` islands (`classicTokenModules`);
- an **array** of module ids → ONE group (a chrome rectangle hosting the
  modules with `unified: true`).

`normalizeClassicbar()` enforces: no module id twice per section; a group keeps
≥ 2 valid members (1 flattens to a loose id, 0 disappears); tokens only loose;
unknown ids discarded.

### widthPercent / autohide

- `widthPercent` sizes the strip on the main axis (centered); everything
  outside the band is transparent **and click-through** (the window input mask
  tracks the content box). Fill forces 100%.
- `autohide: true` leaves a 4px edge tab; leaving the bar arms
  `autohideTimeout`, the band slides out (250 ms) leaving only the tab; the
  exclusive zone drops to 0 while hidden, so maximized windows gain the space.
  The Bar Editor keeps the bar revealed.

Switching engines, editing `classicbar`, or crossing the axis is **hot**: the
host re-applies visuals in place and only recreates module loaders when the
axis flips.

---

## 9. Classic engine — deliberate design decisions

The classic engine reproduces a proven classic bar geometry with the equisdots
vocabulary (`bar.s()` scaling, `colors.*` roles, shared modules). Documented
deliberate differences:

- **Islands keep the bar capsule language** (full capsule ends, translucent
  `surface0` fills, accent solid pills) instead of the classic `base`-colored
  rounded rects — "classic bar geometry + equisdots islands".
- **Vertical bars** keep the bar minimum cross size of `s(70)` because the
  shared compact modules need the width; `classicbar.thickness` only widens a
  vertical bar beyond that.
- **Group chrome tones** use the unified-zone `colors.surface0` (modular) and
  `colors.surface1` @ 0.55 (strip) instead of derived tones.
- **Opacity** only fades the strip (solid/fill); modular island fills keep
  their own translucency.
- **Solid strip radius** derives from the roundness knob and the strip can take
  a 1px border via the bar border keys.
- Modules are equisdots-native (time+date separate islands, weather island,
  tray, update island…), not combined legacy widgets.

---

## 10. Editor pages & pending work

The Bar group of the Bar Editor (`ui/bar/BarEditor.qml`, rail from
`core/EditorNav.js`) already ships: Engine, Position, Style, Zones, Classic
Bar, Modules and Workspaces pages (`ui/bar/editor/*.qml`).

Pending ideas (not implemented):

1. **Presets / import-export**: share a full bar config as JSON.
2. **Per-monitor layouts** (`bar.byMonitor.<name>`): different position/zones
   per display.
