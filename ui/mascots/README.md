# Mascots module

Self-contained Quickshell mascot island. This folder is meant to be extracted
to its own repo: it never imports the shell core, the palette and the settings
source are injected, and the only runtime requirements are Quickshell
(Wayland), Hyprland (`hyprctl cursorpos`, socket2) and a Nerd Font for the
sleepy "z".

```
mascots/
  MascotsOverlay.qml   host: island window, positions, cursor/event polling,
                       moods, hover, click dock, slots
  Mascot.qml           one mascot instance: species resolution, bob, blink
  FlameMascot.qml      default species: little fire with mouth
  CatMascot.qml        pointy ears, stripes, whiskers, pink nose
  DogMascot.qml        floppy ears, eye patch, muzzle, tongue when happy
  EyesMascot.qml       eyes-only: pair of manga eyes with expressions
  MascotFaceEyes.qml   shared face eyes/brows (flame / cat / dog)
  MascotDock.qml       widget miniatures panel that unfolds from the island
  MascotMetrics.js     vendored scale helpers (no shell imports)
```

## Settings (when `settingsPath` is set)

| Key | Values | Default | Meaning |
| --- | --- | --- | --- |
| `mascots.enabled` | bool | `false` | master switch |
| `mascots.species` | `flame` `cat` `dog` `eyes` `mixed` | `flame` | look; `classic` maps to `flame` |
| `mascots.count` | 1..3 | `3` | mascots in the island (width adapts) |
| `mascots.size` | 0.6..1.6 | `1.0` | mascot scale |
| `mascots.position` | `top-left` … `bottom-right` | `top-center` | island position; the dock unfolds toward the screen centre (up when the island is at the bottom) |
| `uiScale` | number | `1.0` | extra user scale |
| `bar.position` / `bar.thickness` | string / px | `top` / 48 | island margin below the bar band |

## Public API (per screen)

`MascotsOverlay` exposes `enabled`, `species`, `count`, `size`, `uiScale`,
`position`, `barPosition`, `barThickness`, `palette`, `settingsPath`,
`widgetStatePath`, `dockWidgetName`, `widgetRectProvider`, `widgetList` and
`widgetLauncher`. The palette object needs `base`, `surface1`, `text`, `crust`,
`red`, `yellow`, `green`, `blue`, `mauve` (colors) and `glassOn` (bool); a
Catppuccin-Mocha fallback is built in. `widgetRectProvider(name, sw, sh,
uiScale)` returns `{ x, y, w, h }` in screen coordinates for widgets that
should hide the island when they overlap it; `dockWidgetName` hides the island
entirely for that widget (e.g. a dock). `widgetList` is an array of
`{ id, label, icon }` cards shown in the click dock; an entry may also carry an
optional `thumb` (path or URL), shown instead of the icon once it loads (e.g. a
live wallpaper preview). `widgetLauncher(id)` is called when one is picked.

## Integration example

```qml
Item {
    Colors { id: themeColors }              // your palette source

    MascotsOverlay {
        palette: themeColors
        settingsPath: "~/.config/hypr/settings.json"
        widgetStatePath: "/run/user/1000/quickshell/current_widget"
        dockWidgetName: "applauncher"
        widgetRectProvider: (name, sw, sh, scale) => computeRect(name)
    }
}
```

The overlay is a click-through layer surface (`qs-mascots`, mask 0x0), one per
screen, and it never captures input.
