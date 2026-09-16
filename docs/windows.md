# Windows & Widgets

The UI is built with [Quickshell](https://quickshell.outfoxxed.me/) (QML shell
environment for Hyprland). This page maps the running windows and the widget
popups; the bar itself is documented in `docs/bar.md`.

## Architecture

Windows mounted by `Shell.qml`:

- **`ui/Main.qml`** — master window: widget stack (`StackView`), morph
  animations, `targetMaster*` metrics and the **IPC handler**
  (`qs ipc call main handleCommand`).
- **`ui/bar/Bar.qml`** — the bar host (dual engine: zones / classic). See
  `docs/bar.md`.
- **`ui/Floating.qml`** — floating layer host (notifications, quick actions,
  OSD-like surfaces).
- **`ui/widgets/Widgets.qml`** — the desktop-widget system (one `WidgetLoader`
  per screen, Bottom-layer windows). See `docs/desktop-widgets.md`.
- **`ui/lock/Lock.qml`** — PAM session lock (`WlSessionLock`).
- **`ui/ScreenshotOverlay.qml`** — region selection, recording controls, QR
  scan, magnifier.

Shared services live in `core/`: `Config` (settings.json), `Caching`
(cache/run/state paths), `Scaler`, `Theme`, `SysData`, `Cava`, `WidgetSync`,
`WindowRegistry.js` (layout math + widget registry) and the compositor adapter
(`Compositor.qml` + `compositors/Hyprland.qml`). Colors come from a local
`Colors` instance in the bar (`ui/bar/Colors.qml`) and the `Theme` singleton
for the desktop widgets.

## Widget popups

Keybinds live in the `hyprland` repo (`config/hypr/keybinds.lua`) and all
dispatch through `qs_manager.sh` → `Main.qml` → `core/WindowRegistry.js`:

| Widget | File | Keybind | Position |
|--------|------|---------|----------|
| Battery | `ui/bar/popups/battery/BatteryPopup.qml` (+ `BatteryPopupAlt.qml`) | SUPER + B | Top right |
| Network | `ui/bar/popups/network/NetworkPopup.qml` | SUPER + N | Top right |
| Volume | `ui/bar/popups/volume/VolumePopup.qml` | SUPER + V | Top right |
| App Launcher | `ui/bar/popups/applauncher/appLauncher.qml` | SUPER + D | Center |
| Clipboard | `ui/panels/clipboard/ClipboardManager.qml` | SUPER + C | Center |
| Calendar | `ui/timex/TimexPopup.qml` (timex subsystem) | SUPER + S | Top center |
| Music Player | `ui/bar/popups/music/MusicPopup.qml` | SUPER + M | Top left |
| Davincix (wallpaper) | `ui/panels/davincix/DavincixPicker.qml` | SUPER + W | Center |
| Guide / About | `ui/bar/popups/guide/GuidePopup.qml` | SUPER + H | Center |
| System Monitor | `ui/bar/popups/system-monitor/SystemMonitor.qml` | SUPER + I | Center |
| Updater | `ui/bar/popups/updater/UpdaterPopup.qml` | SUPER + U | Center |
| Quick Notes | `ui/panels/quicknotes/QuickNotes.qml` | SUPER + Y | Center |
| RSS Reader | `ui/panels/rss-reader/RssReader.qml` | SUPER + O | Center |
| File Search | `ui/panels/file-search/FileSearch.qml` | SUPER + ' | Center |
| Focus Time | `ui/panels/focustime/FocusTimePopup.qml` | SUPER + SHIFT + T | Center |
| Display Scale | `ui/panels/scale/ScalePicker.qml` | SUPER + Z | Center |
| Idle | `ui/panels/idle/IdlePopup.qml` | SUPER + P | Center |
| Window Controls | `ui/panels/window-controls/WindowControls.qml` | SUPER + SHIFT + B | Center |
| Quick Actions | `ui/panels/quickactions/` (`DrawAction.qml`, `SystemUsage.qml`, `Timer.qml`) | (internal) | Varies |
| Bar Editor | `ui/bar/BarEditor.qml` | SUPER + SHIFT + S / D | Center |
| Widget Redactor | `ui/widgets/WidgetRedactor.qml` | SUPER + SHIFT + W | Center |
| Lock | `ui/lock/Lock.qml` | SUPER + L (`lock.sh`) | Fullscreen |

Widget geometry is defined in `core/WindowRegistry.js` (`getLayout()` +
`positionLayout()`), with responsive scaling based on screen size and the user
UI scale.

## Wallpaper subsystem (davincix)

The wallpaper picker is the frontend of **davincix**, which lives in its own
repo ([`equisdots/davincix`](https://github.com/equisdots/davincix)):

- UI: `ui/panels/davincix/DavincixPicker.qml` composes its view components
  under `ui/panels/davincix/components/` (`grid/`, `filter/`) plus `lib/`.
  It only decides **what** to apply; the kernel decides **how**.
- Kernel: resolved through `$DAVINCIX_CLI` or `~/.local/bin/davincix` (dots
  installs it from the repo: `set`, `fetch`, `current`, `thumbs`, `search`,
  `stop`, `import`, `slideshow`, `keys`, `paths`).
- Callers: the picker itself, `qs_manager.sh` (`thumbs`, `current`),
  `init.sh` (random first-run) and `Lock.qml` / `sddm-colors.sh`
  (read `current_wallpaper.png`).

## IPC system

`qs_manager.sh` (deployed to `~/.config/hypr/scripts/`) talks to `Main.qml`
through Quickshell IPC:

- `qs_manager.sh toggle <widget>` — open/close a named widget (the widget names
  are the `WindowRegistry.js` keys, e.g. `bar-editor`, `calendar`, `volume`).
- `qs_manager.sh close` — close the current widget (flushes state first).
- `qs_manager.sh <number>` — switch to workspace N (fast path).
- `qs_manager.sh <number> move` — move the active window to workspace N.
- `qs_manager.sh prev` / `next` — cycle workspaces.

## Data watchers

Background scripts in `core/scripts/watchers/` feed real-time data into QML
(they run on demand from the bar pollers):

- `audio_fetch.sh` / `audio_wait.sh` — audio devices state
- `battery_fetch.sh` / `battery_wait.sh` — battery percentage and status
- `bt_fetch.sh` / `bt_wait.sh` — Bluetooth state
- `network_fetch.sh` / `network_wait.sh` — WiFi and Ethernet status
- `kb_fetch.sh` / `kb_wait.sh` — keyboard layout
- `sys_fetcher.sh` — CPU, RAM, temperature, network I/O
