# Wallpaper picker: interactive scenes

The davincix picker is a thin frontend over the kernel CLI: the kernel lists
thumbnails and applies wallpapers, the UI decides what to apply. Interactive
scenes (`xwww` scene engine) are ordinary entries in that model.

## Entry naming

Scenes appear in the thumbnail directory as `scn_<name>.jpg` (videos use the
`000_` prefix, images keep their file name). The picker normalizes names in
`getCleanName()`:

- `scn_<name>.jpg` -> `<name>` (the scene directory);
- `000_<name>` -> `<name>`;
- `__` -> `/` (flattened nested paths).

`applyWallpaper()` resolves the source path with `getCleanName()` and calls
`davincix set <path> --monitors <outputs> --transition <selected>`. The kernel
detects the scene directory and starts it with the chosen entry transition.

## Card badge

The card component marks scenes with a `JS` badge in the top-right corner
(`isScene`, same position as the video play badge). No live preview is needed:
the thumbnail is the scene cover.

## Applying, current state and removal

- Applying works with a mouse click and `Return`; the transition selector in
  the filter bar applies to scenes too.
- When the picker opens, the shell queries `davincix current --thumb-name` and
  passes it as the initial target, so the active scene is selected.
- `Delete` moves the whole scene directory to the trash through `davincix rm`.

## Related documentation

- `equisdots/davincix` - `docs/interactive-scenes.md` (kernel contract).
- `equisdots/background` - `docs/interactive-scenes.md` (scene collection).
