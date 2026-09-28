# Development

Working notes for the equisdots desktop stack. There is no CI: each repo ships
a local check script and the maintainer runs it before pushing.

## Local checks

| Repo | Command | What it checks |
|---|---|---|
| shell | `scripts/check.sh` | `qmllint` over every `.qml` file, `node --check` over the JS modules |
| hyprland | `scripts/check.sh` | `luac -p` over every config module, `bash -n` over the scripts |
| palettes | `scripts/check.sh` | palette schema + `index.json` consistency |
| theme-sync | `scripts/check.sh` | `compileall` + CLI smoke test (list / dry-run) |

The shell checks need the Qt declarative tools (`qmllint`) and `node`. The
hyprland checks need `luac` (`shellcheck` is used as an advisory when present).

## Pitfalls

- **Writing a loaded `.lua` file under `~/.config/hypr` triggers a full
  Hyprland config reload.** Apply runtime changes with `hyprctl eval` and write
  the Lua overrides only on settle/close; `core/scripts/hypr-effects.sh` is the
  reference implementation.
- **Pages are created on first open.** Values that affect the first layout
  (e.g. `uiScale`) must be read synchronously from `Config` before the first
  paint, or the page will render at the wrong scale and re-layout afterwards.
- **Editor pages cannot redefine FINAL properties of their root type**
  (`enabled`, `opacity` on `Item`, ...); use prefixed local properties.
- **Inline components used as view delegates** must declare the model role as a
  `required property var modelData`.
- **Give containers an explicit width** before binding a child's width to
  `parent.width`; circular width bindings collapse to 0 px (silent empty text).
- **Keep `sysinfo.sh` fast.** The About page waits for it: commands that trigger
  network scans (`nmcli` wifi listing took ~5 s) stall the whole page. Prefer
  instant sources (`iwgetid -r`).
- Reload the shell while developing with
  `qs ipc call main forceReload`; QML errors are visible by running a copy of
  the shell in the foreground (`cp -r` the config dir and run
  `quickshell -p <copy>/Shell.qml`).
