# Bar System — Architecture & Customization

The bar is the shell's position-agnostic bar window: `ui/bar/Bar.qml`, a
single zones engine on any screen edge (`top` / `bottom` / `left` / `right`).
A **master switch** (`bar.enabled`) unmaps it entirely — no UI, no reserved
edge, no input — and maps it back with the same layout when switched on (it is
hot: the live shell reacts to the settings file; no reload).

The core bar lives alone under the `bar` key of `settings.json`. On top of
that, **complete bars can ship as plugins** (`provides.bar.provider`): a
plugin bar is an always-on component mounted by `ui/PluginHosts.qml` with its
own master switch and its own settings page — see §8. The two worlds are
independent: the core bar's switch and each plugin bar's plugin switch decide
what runs; nothing auto-replaces anything.

---

## 1. File layout

```
shell/
  Shell.qml                  entry point (mounts Main, Bar, Floating, Widgets)
  core/                      services + contracts (Config, Caching, Scaler,
                             WindowRegistry.js, Theme, SysData, Cava, WidgetSync,
                             Compositor + compositors/, scripts/watchers/)
  ui/bar/
    Bar.qml                  the bar host PanelWindow: geometry, pollers,
                             IPC, zones engine, master switch
    Zone.qml                 renders ONE zone as a Row (horizontal) / Column
    ModulePill.qml           shared island pill (all visual plumbing)
    Colors.qml               palette loader + semantic role derivation
    BarLayout.js             pure-JS engine: zones, catalog, migration, presets
    modules/*.qml            the 18 modules
    edit/                    editor controls (FieldCard, ToggleCard, steppers…)
    editor/                  editor pages + SearchOverlay + persist-hypr.sh
    popups/                  popups triggered by bar modules
```

The palettes themselves (**frozen shared path**) live at
`~/.config/hypr/scripts/quickshell/dock/palettes/`, deployed from the
`equisdots/palettes` repo (also read by `theme-sync` and `colors.lua`).
Plugin bars live in their plugin's tree (`ui/plugins/<id>/`), like every
other plugin UI face.

---

## 2. Data flow

```
settings.json
   "bar": {
     "enabled": true | false,     // master switch (unmaps the bar windows)
     "position", "palette", "thickness", "edgeGap",
     "zones": [ ... ]
   }
        |
        v
Bar.qml (settingsReader, directory watcher)
   barConfig = BarLayout.getBar(parsed)      // "bar" key
        |
        v
Bar.qml -> Repeater -> Zone.qml -> module Loaders
        ^                        |
        |-- shared state: bar.* (pollers/watchers) + colors.* (palette)
```

- **The config lives under `"bar"`** (pre-0.2 `"dock"`/`"topbar"` configs are
  migrated once by `BarLayout.getBar()`, the single migration entry point).
  The host watches the `~/.config/hypr` **directory** (atomic tmp+`mv` writes
  kill file watches) with content-compare choke points, so live editing is
  reliable while the shell runs. The old `barEngine` / `classicbar` keys are
  no longer read; leftover keys in user files are ignored, never rewritten.
- **Data state** (workspaces, wifi, volume, battery, music, clock, sysmon…)
  is fetched by `Process` watchers declared in `Bar.qml` and exposed on the
  `bar` object injected into every module.
- **Colors** always come from `ui/bar/Colors.qml` (palette system), never
  from Matugen.

---

## 3. `settings.json` → `bar` schema

Everything the editor edits lives under one key (defaults from
`BarLayout.defaultBar()`):

```jsonc
{
  "bar": {
    "enabled": true,                // master switch (General page)
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

- **`bar.enabled`** is the master switch: the editor's General page toggles
  it; off unmaps every bar window (no reserve, no input) while the rest of
  the config — zones, visuals, everything — is preserved for the way back.
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
| General (`d_general`)         | `bar.enabled` (+ overview)        | `Bar.qml` (master switch)    |
| Position (`d_position`)       | `bar.position`                    | `Bar.qml` geometry           |
| Style (`d_style`)             | `bar.pillBg/pillSolid/barBg/…`    | `Bar.qml` → modules          |
| Zones (`d_zones`)             | `bar.zones`                       | `BarLayout.js` CRUD + `Zone.qml` |
| Modules (`d_modules`)         | `bar.modules.<id>.*`              | modules read `bar.moduleConfig` |
| Workspaces (`d_workspaces`)   | `bar.workspacesMarker*`           | `WorkspacesModule.qml`       |
| Palette (`d_palette`, Theme)  | `bar.palette`, `bar.border*`      | `Colors.qml`, `colors.lua`   |
| Shadows (`d_shadows`, Theme)  | `shadows.*`                       | `ui/Main.qml`, `Bar.qml`/`Zone.qml` |
| Glass (`d_glass`, Theme)      | `glass.*`                         | `Colors.qml`, `Theme.qml`, hyprland `layers.lua` |

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
| `setBarEnabled(bar, v)` | master switch (`bar.enabled`, written by the General page) |
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

Empty-workspace markers (global, via `WorkspacesModule`):

- `bar.workspacesMarker` — `"number"` (default) | `"dot"` | `"letter"`
  (A, B, C…) | `"custom"`.
- `bar.workspacesMarkerText` — the character shown when marker is `"custom"`
  (up to 4 chars — any Unicode glyph).
- Only EMPTY workspaces use the marker; occupied workspaces show app icons.
  Editor: Workspaces card.

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

## 8. Plugin bars (`provides.bar.provider`)

A plugin can ship a **complete bar** — its own window(s), modules, design and
placement. The manifest declares it next to any other contributions:

```json
"provides": {
  "bar": {
    "provider": { "comp": "bar/MyBar.qml", "label": "My Bar", "icon": "" }
  }
}
```

How it runs:

- **Mount**: `ui/PluginHosts.qml` mounts the comp exactly like a host adapter
  (relative load inside the shell tree, injected `host` SDK handle, optional
  `surfaces` registration and `frameObstacle` publication). Managed plugins
  only — the comp lives in the shell tree so it may import the core kit
  (`qs.core`, `qs.ui.bar`, `qs.ui.bar.edit`); user plugins ship pages and
  payloads instead (same rule as host adapters).
- **Switch**: the plugin's master switch owns it (`plugins.<id>.enabled` or
  the manifest's `toggle`, stored in the plugin's **own** settings file). Its
  settings page is its menu; the Plugins group lists it like any other page.
- **Placement**: the plugin owns it. The comp creates its `PanelWindow`s
  directly (usually one per `Quickshell.screens`, with an `exclusiveZone` to
  reserve the edge) or goes through the SDK surface manager for fancier
  reservations; the core never positions plugin windows.
- **Coexistence**: plugin bars and the core bar are independent switches.
  If both target the same edge they simply stack; disable the core bar
  (Bar group → General → *Bar enabled*) when a plugin bar should own the
  screen edge. Nothing auto-replaces anything.
- **Palette**: read `host.colors` (live palette) — never hardcode.

POC fixture: `equisdots/plugins` → `plugins/hello-bar` (a minimal top band:
clock + date, its own page, `provides.bar.provider`). It is the reference for
the contract.

---

## 9. Pending ideas (not implemented)

1. **Presets / import-export**: share a full bar config as JSON.
2. **Per-monitor layouts** (`bar.byMonitor.<name>`): different position/zones
   per display.
