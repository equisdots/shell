# Bar Modules — Contract & Customization Guide

Every module is a small QML file under `ui/bar/modules/` that renders one island
pill. Thanks to `ModulePill` (the shared component), a module does not
re-implement backgrounds, borders, hover scale, entrance animations or clicks —
it only declares *what* it shows and *what* it does.

The same modules are used by **both bar engines** (zones and classic).

---

## 1. The module contract (what Zone injects)

When `Zone.qml` (or `ClassicBar.qml`) instantiates a module it always injects
these 7 properties:

| property                  | type   | meaning |
| ------------------------- | ------ | ------- |
| `bar`                     | var    | the bar host: all shared state + helpers (`bar.s()`, `bar.orientation`, `bar.timeStr`, `bar.wifiSsid`, `bar.moduleConfig(id)`, …) |
| `colors`                  | var    | the active palette (`colors.base`, `colors.mauve`, `colors.surface1`, …) |
| `zoneReady`               | bool   | zone entrance finished (drives the per-module stagger) |
| `slotIndex`               | int    | module position in its zone (stagger offset) |
| `effectiveBorderWidth`    | real   | zone border width (0 if unified) |
| `effectiveBorderColor`    | string | zone border color role |
| `unified`                 | bool   | zone is a single continuous pill |

---

## 2. `ModulePill` API

A module's root is a `ModulePill`; its children become the pill content.

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../core"
import ".."

ModulePill {
    id: mod
    moduleId: "time"          // keys the per-module config (bar.modules.time)

    // --- injected (declared as required inside ModulePill) ---
    // bar, colors, zoneReady, slotIndex, effectiveBorderWidth,
    // effectiveBorderColor, unified

    // --- orientation helpers (read-only) ---
    // horizontal: bool   (true on top/bottom bars)
    // compact:    bool   (vertical bar: narrower island)

    // --- per-module personalization (read-only) ---
    // moduleCfg:          normalized bar.modules.<moduleId> (see §5)
    // effectiveAccentRole: moduleCfg.accent or the module's own accentRole
    // accentTint:         host is tinting state colors (classic flat strip)

    // --- visuals ---
    accentRole: "color6"      // colors.* role; when accentActive → solid accent island
    accentColor: "transparent"// direct color override (dynamic values, e.g. battery)
    accentActive: true        // whether the accent fill is shown (state-driven)
    pulse: false              // pulsing ring behind content (update/recording)
    bgRole: "surface0"        // idle island tone
    bgHoverRole: "surface1"
    idleRole: "text"          // content color role when idle
    hoverRole: ""             // content color role on hover (falls back to idleRole)
    fullHeight: false         // use bar.barHeight instead of bar.pillHeight
    showState: true           // collapse the pill (width/height animate to 0)
    noFill: false             // force transparent background (media/tray)
    fillMode: "default"       // module config fill ("default"/"on"/"off")
    padH / padV: int          // inner padding

    // --- signals ---
    // clicked()   rightClicked()   wheelUp()   wheelDown()

    // --- content color (bind text color to it) ---
    // contentColor -> colors.base on accent islands, else idle/hover role

    Text { color: mod.contentColor }
}
```

### Visual modes

- **Standard island** (help, search, settings, time, tray…): semi-transparent
  `surface0` → `surface1` on hover.
- **Accent island** (wifi, bluetooth, volume, battery, keyboard, sysmon,
  update, recording): solid colored pill; content drawn in `colors.base`.
  Driven by `accentRole`/`accentColor` + `accentActive`.
- **Transparent island** (media): `noFill: true`, only border.
- **Unified zone**: pills become transparent and the zone background takes over
  (`unified` prop).

---

## 3. Orientation / compact mode

On **vertical bars** (`bar.orientation === "vertical"`) the pill becomes a
narrow vertical island and every module is expected to show **reduced**
content:

| module | horizontal (full) | compact (reduced) |
| --- | --- | --- |
| help / search / settings | icon | icon (unchanged) |
| update | icon + pulse | icon + pulse |
| recording | icon + blink | icon + blink |
| time | `HH:mm:ss` | `HH:mm` |
| date | full date (typewriter) | hidden |
| media | art + title + controls | music icon |
| workspaces | row of ws pills | **column** of ws pills |
| tray | single row of icons | 2-column grid |
| keyboard | icon + layout | icon |
| wifi | icon + ssid | icon |
| bluetooth | icon + device | icon |
| sysmon | icon + cpu + ram | two tiny stacked values |
| volume | icon + percent | icon |
| battery | icon + percent | icon |
| weather | weather glyph + temperature | glyph over temperature |
| focus | app icon + window title | app icon |

`weather` and `focus` ship **disabled by default** — enable them in the Bar
Editor → Modules (their entries exist in `bar.zones` with `enabled: false` and
are re-added disabled after updates, so existing bars never change on their
own).

- **weather**: shows `bar.weatherIcon` + `bar.weatherTemp` (data polled from
  the timex engine through the `ui/bar/popups/calendar/weather.sh` shim; the
  island fill follows the weather code color `bar.weatherHex`); click opens the
  calendar popup.
- **focus**: shows the title of the currently focused window
  (`bar.focusTitle`, via the compositor adapter → Hyprland `activewindow -j`),
  with an app glyph derived from the window class. The island collapses on an
  empty desktop; click opens the app launcher.

Modules branch with `visible: mod.horizontal` / `visible: mod.compact` inside
the content.

### Workspaces module — empty markers

Empty workspaces (no windows) render a configurable marker instead of the
workspace number:

- `bar.workspacesMarker`: `number` (default) / `dot` / `letter` (A, B, C… by
  index) / `custom`.
- `bar.workspacesMarkerText`: the glyph for `custom` — any Unicode character
  (up to 4 chars).
- Occupied workspaces always show their app icons; markers only appear on empty
  pills (including an empty ACTIVE workspace). Marker color follows the pill
  state (active/hover/empty).

The active-workspace highlight color can be themed per palette through the
`workspaceActive` role (see `docs/themes.md`).

## 4. Adding a new module

1. Create `ui/bar/modules/MyModule.qml` (root = `ModulePill`, imports
   `"../../../core"` and `".."`).
2. Register it in **`ui/bar/BarLayout.js`** `MODULES`:
   ```js
   { id: "mymodule", label: "My Module", icon: "󰂓",
     component: "modules/MyModule.qml" }
   ```
   (`component` is resolved by `Zone.qml` relative to `ui/bar/`.)
3. Give it a default zone placement if you want it on fresh installs
   (`normalizeBar` re-adds catalog modules not present in the config; see
   `LEGACY_START_IDS` / `LEGACY_CENTER_IDS` / `LEGACY_END_IDS` and
   `NEW_ALWAYS_DISABLED`).
4. If it needs live data, read `bar.<prop>` (add a watcher in `Bar.qml` if
   needed) and read per-module options through `mod.moduleCfg`
   (`bar.moduleConfig(id)`).

---

## 5. Per-module personalization (implemented)

Options live in `settings.json` under `bar.modules.<id>` and are normalized by
`BarLayout.defaultModuleConfig()` / `normalizeModuleConfig()`:

```jsonc
"modules": {
  "time": {
    "icon": "",            // override the module glyph ("" = default)
    "color": "",           // content color: role name or #hex ("" = idleRole)
    "accent": "",          // accent role ("" clears the module default)
    "fill": "default",     // "default" | "on" | "off"
    "colors": {},          // per-slot overrides (workspaces: active,
                           // activeText, occupied, empty, hover, marker,
                           // markerEmpty)
    "size": 0,             // font px override (0 = module default)
    "effect": "",          // view effect ("typewriter" for the clock)
    "cursor": true         // blinking cursor for the typewriter effect
  }
}
```

Pure helpers (`BarLayout.js`): `moduleConfig`, `setModuleValue`,
`setModuleIcon`, `setModuleColor`, `setModuleFill`, `setModuleAccent`,
`setModuleSize`, `setModuleEffect`, `setModuleCursor`, `setModuleColorSlot`,
`setGlobalIconColor` (bar-wide `bar.iconColor`).

The editor renders all of this in the **Modules** page
(`ui/bar/editor/ModulesPage.qml`), including palette-role dropdowns and the
colour-dot sliders for the workspaces slots.
