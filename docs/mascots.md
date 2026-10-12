# Mascots & the notch (Nyx)

The notch / mascot island is the **Nyx** module (a separate repo, deployed by
the dots installer to `ui/nyx/`, git-ignored here) wrapped by `ui/Mascots.qml`.
Nyx never imports the shell: the wrapper injects the live palette, the settings
path, the widget-occlusion hooks and — new — the two discovered catalogs below.
Authoring the species QML and the overlay API is documented in the Nyx README
(`ui/nyx/README.md`); this file documents the **shell-side integration**:
discovery, the notch cards and the editor.

## Discovery (folders)

Mascot species and notch cards are **discovered from folders**, so a user can
drop a file and have it recognised without touching a repo. The scan lives in
`core/scripts/mascots_scan.sh` and is driven by the `MascotsCatalog` singleton
(`core/MascotsCatalog.qml`), which runs it with these dirs:

| What | Shipped (repo) | User |
|---|---|---|
| Species | `ui/nyx/mascots/` | `~/.config/hypr/mascots/species/` |
| Notch cards | `notch/` | `~/.config/hypr/mascots/notch/` |

Rules:

- Each file is a JSON **object**, or an **array** of objects (the repo ships an
  array; a user drops a single object). Nothing else in the folder is read.
- The **user dirs are scanned first** and win on `id` collisions, so a user file
  overrides a shipped one.
- Every entry gets a `_base` field (its directory) so a relative QML `entry`
  can be resolved.
- `MascotsCatalog.refresh()` re-runs the scan (the shell also scans on start).

`MascotsCatalog` exposes `mascots` and `things`, sorted by `order` then label.

## Mascot species

A species manifest (`*.json`):

```json
{ "id": "moon", "label": "Moon", "icon": "", "entry": "Moon.qml", "order": 100 }
```

- `entry` — a QML file next to the manifest. When present, `Mascot.qml` loads it
  through a `Loader` and injects the mascot contract (`mood`, `lookX`, `lookY`,
  `tint`, `crust`, `text`, `red`, `blinking`, `clock`, `palette`, `options`).
- Without `entry`, `id` is a **built-in kind** (`flame`, `cat`, `dog`, `eyes`,
  `dots`, `watcher`) rendered by `Mascot.qml`'s own components.
- `customizable` — array of option names the species accepts (`"color"`,
  `"size"`); the editor shows one control per entry. Omitted = none.
- `controls` — the richer form of the same idea, when a species needs more than
  colour/size: `[{"type":"color"},{"type":"size"},{"type":"text","key":"user",
  "label":"User","placeholder":"…","default":"…"}]`. A `text` control stores a
  string under `options.<key>` (e.g. the GitHub username).
- `popover` — optional QML file next to the manifest. A species that declares
  one becomes **clickable**: clicking its mascot opens that popover (see below).
- Shipped species (built-ins + the shell-agnostic "info" species: `battery`,
  `cpu`, `memory`, `wifi`, `volume`, `temperature`, and `github`) are declared in
  `ui/nyx/mascots/species.json`.

Which species are shown, and in which order, comes from
`settings.json → mascots.species`:

| Value | Meaning |
|---|---|
| `"watcher"` (string) | every mascot is that kind; `mascots.count` (1..8) repeats it |
| `["cat","dog","battery"]` (array) | one mascot per id, in order; the island width follows the array length |

Ids not present in the catalog fall back to a built-in kind when possible.

## Appearance (colour & size)

Per-species overrides live in `settings.json → mascots.options.<id>` and are
injected into each mascot through the `options` contract:

```json
{ "mascots": { "options": {
    "battery": { "color": "green", "size": 1.2 },
    "cpu": { "color": "#f9e2af" } } } }
```

- `color` — a palette role name (`red`, `green`, …) or a `#hex`; empty/absent
  uses the species' own accent (which may be dynamic, e.g. battery by level).
- `size` — a content scale (0.6..1.8; default 1.0).

The species receives these via `options` and applies them (the info species do
it in `InfoMascot`: `options.color` overrides the accent, `options.size` scales
the content). Only options listed in a species' `customizable`/`controls`
manifest fields get an editor control; a `text` control (e.g. the GitHub
username) is written on the field's `editingFinished`.

## Clickable mascots & popovers

A mascot whose species declares a `popover` is **clickable individually**:
clicking it opens its popover in the same panel slot as the dock. The panel
sizes itself to the popover's `implicitWidth/Height` and grows/shrinks with the
reveal. The popover closes when you click the island again, or anywhere outside
(the overlay uses a `HyprlandFocusGrab`); clicking the island elsewhere opens the
dock as before.

## Notch cards ("things")

A card descriptor (`*.json`):

```json
{ "id": "weather", "label": "Weather", "icon": "󰖐", "exec": "…", "thumb": "" }
```

- `exec` — a shell command run when the card is picked.
- Without `exec`, the card opens the shell panel with that `id` through
  `qs_manager.sh open <id>`.
- `enabled: false` hides a shipped card; `thumb` sets a preview image.
- The shipped defaults are `notch/defaults.json` (the 18 shell widgets).

`ui/Mascots.qml` builds the dock's `widgetList` from `MascotsCatalog.things`
(filtering `enabled === false`) and runs a card's `exec` in the launcher; the
`wallpaper` card keeps its live preview thumbnail.

## Editor (Settings → Mascots)

Theme → Mascots edits `settings.json → mascots`. The **Species** section is an
ordered, drag-reorderable lineup:

- **Ordered list** — the active species, one row each (drag handle, icon, label,
  remove ✕). Top → bottom maps to left → right in the island.
- **Drag & drop** — dragging the handle reorders the lineup (a floating ghost +
  an insertion indicator); the order is written to `mascots.species` as an
  array. Only the handle starts a drag, so the page can still scroll.
- **Add** — chips for the discovered species that are not in the lineup yet;
  clicking one appends it.
- **Appearance** — controls per row for the species' declared `customizable`/
  `controls`: a colour dot (tap to cycle palette roles; `A` = auto), a size
  stepper (− / +) and/or a text field (e.g. the GitHub username). They write
  `mascots.options.<id>`.
- The legacy string + `count` mode is still read; editing switches to the array
  form.

## Adding your own

Species — drop two files and restart the shell (or `MascotsCatalog.refresh()`):

1. `~/.config/hypr/mascots/species/moon.json` (the manifest above).
2. `~/.config/hypr/mascots/species/Moon.qml` (a QML root declaring the mascot
   contract props; no shell imports). Then enable it in the editor.

Card — drop `~/.config/hypr/mascots/notch/<id>.json` and restart.
