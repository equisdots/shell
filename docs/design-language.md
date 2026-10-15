# Design language

The shell's visual system: **Material-You structure on a single synced palette.**

Two things are deliberately *kept* from the previous identity and are
non-negotiable:

- **Colour = the project's synced base16 palette.** Every colour role derives
  from the active palette file (`dock/palettes/<slug>.json`) through
  `core/Theme.qml`, so `theme-sync` keeps working exactly as before. MD3 roles
  are *derived* from that palette, never seeded elsewhere.
- **Type = Hack Nerd Font**, glyph icons included. No emoji (project rule).

What changed is the **structure**: shape, spacing, elevation, outlines, state
layers and motion now come from one Material-You token set, so panels and
widgets share an ordered dimension system instead of ad-hoc values.

## Tokens (`core/Theme.qml`)

Scales read `settings.json -> appearance.{shapeScale,densityScale,motionScale}`
(default `1`) — editable live from **Settings → Theme → Appearance**
(`ui/bar/editor/AppearancePage.qml`, three `StepperCard`s, range 0.60–1.60).
Because `Theme` watches `settings.json`, changing a scale re-applies every panel
and widget immediately (verified: a widget's corner radius changes without a
shell reload).

| Group | Tokens | Notes |
|---|---|---|
| Shape | `radiusXs/Sm/Md/Lg/Xl/Full` (4/8/12/16/28/full dp) | corner radii |
| Spacing | `gap2xs/Xs/Sm/Md/Lg/Xl` (2/4/8/12/16/24 dp) | 4dp grid |
| Elevation | `surfaceContainerLowest/Low/…/Highest` | tonal surfaces by lightness |
| Outline | `outline`, `outlineVariant` | MD3 borders |
| State | `stateHover` (0.08), `statePress` (0.12), `stateLayer(c, amt)` | hover/press overlays |
| Motion | `durShort/Medium/Long` (150/250/400 ms) | scaled by `motionScale` |

`base`/`text` stay the palette-driven anchor; `surfaceContainer*` and `outline*`
are alpha-aware mixes of them (`Theme.tone(amount)`), so **glass mode still shows
the backdrop through** and light/dark palettes both behave.

## Rules

1. **No magic numbers** for radius, spacing or motion — use the tokens.
2. **A card is** `surfaceContainerHigh` fill + `outlineVariant` border +
   `radiusLg` corners (`core/GlassCard.qml`).
3. **Order by the 4dp grid**: margins/paddings pick the nearest `gap*` token.
4. **States are overlays**, not colour swaps: draw `stateLayer(accent, stateHover)`
   on hover, `statePress` on press.
5. **Elevation is tonal**: to raise a surface use the next
   `surfaceContainer*` step — do not invent opacity values.
6. **Density wins**: layouts size to content (see `nyx-niri/DESIGN.md` §4) — the
   tokens make that consistent, they never justify blank space.

## Migration status

- [x] `Theme.qml` token layer (shape/spacing/elevation/outline/state/motion).
- [x] Desktop-widget faces (`ui/widgets/faces/*`) on `surfaceContainerHigh` /
      `outlineVariant` / `radiusLg` via `core/GlassCard.qml`.
- [x] Bar popups (`ui/bar/popups/**`) — 8 files: outer card `radiusLg` +
      `surfaceContainerLow` + `outlineVariant`; inner tiles `radiusMd` +
      `surfaceContainer`; chips `radiusSm`; state layers.
- [x] Panels (`ui/panels/**`) — davincix, focustime, idle, palette, plugins,
      quickactions, scale, window-controls.
- [x] Editor primitives (`ui/bar/edit/**`) and pages (`ui/bar/editor/**`):
      outer cards on the tokens, uniform `gap*` section spacing.
- [x] Settings tabs (`ui/settings/tabs/**` — General/Keyboard/Monitors/Startup):
      **redesigned** to the modern page scaffold — page header (title +
      description), single column of section cards (`surfaceContainerLow` +
      `outlineVariant` + `radiusLg`, sized to content) with label/hint-left,
      control-right rows; page inset `gapLg`, section gap `gapXl`, row gap
      `gapMd`; in-flow "+ Add"; `displayMargin*` zeroed on non-interactive
      lists (fixes the Keybind rows drawing over the Workspaces card).
- [x] Editor chrome (`ui/bar/BarEditor.qml`): rail is **flat** — no per-group
      rail line and no subtab indent, so selecting a page shows only the active
      pill (fill) + label; the brand header is a live **base16 swatch strip**
      (16 squares, no title/box).
- [~] Bar (`ui/bar/ModulePill.qml`): already parameterised by `bar.pillRadius()`
      and `bar.s()`; map to the tokens only if the bar engine is touched.

Conventions actually applied during the migration:

- Import core (`../../../core` or `qs.core`) wherever `Theme` is referenced.
- Preserve `bar.s(...)` scaling: write `bar.s(Theme.radiusLg)` and keep the
  `bar ? ... : fallback` guards.
- Outlines that were `colors.surface1`/`surface2` → `Theme.outlineVariant`.
- Hovers that were `Qt.alpha(accent, x)` → `Theme.stateLayer(accent, Theme.stateHover)`.
- Semantic accents (mauve/text/crust/red/green/…) are kept as accent roles; only
  surface-role fills/borders became tokens.
- Structural width/height reserves and sub-4dp micro-insets stay raw.

