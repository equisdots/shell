import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"
import "../core/WindowRegistry.js" as LayoutMath
import "BarLayout.js" as BarLayout

// ============================================================================
// Bar — the position-agnostic bar.
//
// Replaces the old top-only TopBar.qml. The same island-pill aesthetic and all
// module/data machinery are preserved, but the bar can sit on any screen edge:
//
//   position: "top" | "bottom" | "left" | "right"
//   orientation: derived from position (horizontal / vertical)
//
// The visual + layout config lives in settings.json under "bar" (see
// BarLayout.js). Old "topbar" settings are migrated on first load. Colors
// come from the Matugen-free palette system (bar/Colors.qml).
//
// Data plumbing (watchers/pollers) is centralized here; modules read state
// through the `bar` object — same contract as the old TopBar, so existing
// modules keep working untouched while we migrate them to ModulePill.
// ============================================================================

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow

            required property var modelData
            screen: modelData

            // Inline replica of the parent dir's Caching.qml so this component
            // stays self-contained inside bar/.
            QtObject {
                id: paths
                readonly property string home: Quickshell.env("HOME")
                readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")
                readonly property string cacheDir: home + "/.cache/quickshell"
                readonly property string stateDir: home + "/.local/state/quickshell"
                readonly property string runDir: (xdgRuntimeDir !== "" ? xdgRuntimeDir : "/tmp") + "/quickshell"
                readonly property string logDir: runDir + "/logs"
                function getCacheDir(name) {
                    let envPath = Quickshell.env("QS_CACHE_" + name.toUpperCase());
                    let p = envPath ? envPath : (cacheDir + "/" + name);
                    Quickshell.execDetached(["mkdir", "-p", p]);
                    return p;
                }
                function getStateDir(name) {
                    let envPath = Quickshell.env("QS_STATE_" + name.toUpperCase());
                    let p = envPath ? envPath : (stateDir + "/" + name);
                    Quickshell.execDetached(["mkdir", "-p", p]);
                    return p;
                }
                function getRunDir(name) {
                    let envPath = Quickshell.env("QS_RUN_" + name.toUpperCase());
                    let p = envPath ? envPath : (runDir + "/" + name);
                    Quickshell.execDetached(["mkdir", "-p", p]);
                    return p;
                }
                function getLogDir(name) {
                    let envPath = Quickshell.env("QS_LOG_" + name.toUpperCase());
                    let p = envPath ? envPath : (logDir + "/" + name);
                    Quickshell.execDetached(["mkdir", "-p", p]);
                    return p;
                }
            }

            // ================================================================
            // SCALING (inlined — avoids importing Scaler.qml from the parent dir)
            // ================================================================
            property real uiScale: 1.0
            readonly property real baseScale: LayoutMath.getScale(
                barWindow.screen ? barWindow.screen.width : 1920,
                barWindow.screen ? barWindow.screen.height : 1080,
                barWindow.uiScale)
            function s(val) { return LayoutMath.s(val, baseScale); }

            // ================================================================
            // THEME COLORS (Matugen-free)
            // ================================================================
            Colors {
                id: barColors
            }
            // Exposed as a property so modules/zones can use `colors.<role>`
            // exactly like they did with the legacy MatugenColors component.
            readonly property var colors: barColors

            // ================================================================
            // DOCK CONFIG (settings.json "bar" key)
            //
            // CUSTOMIZATION HOOK: every visual/layout value the mega menu edits
            // lands here. `syncBarConfig()` copies the parsed barConfig into
            // plain properties in ONE synchronous pass so orientation/geometry/
            // zones always stay consistent (readonly binding chains evaluate
            // lazily and caused stale orientation bugs).
            // ================================================================
            property var barConfig: BarLayout.defaultBar()
            property var zones: barConfig.zones
            // Becomes true only after settings.json has been read AND the bar
            // config synced, so uiScale/baseScale are final before any module
            // renders (bar.s() is a function, so QML can't reactively rescale).
            property bool configReady: false
            property string position: "top"
            property string orientation: "horizontal"
            property string paletteName: "x"
            property real thickness: 48
            property real edgeGap: 8
            property real roundness: 1.0
            property bool pillBg: true
            property bool pillSolid: false
            // "barBg" — solid/translucent background strip behind the whole bar;
            // islands then float INSIDE it instead of being standalone pills.
            property bool barBg: false
            property real borderWidth: 0
            property string borderColor: "surface1"
            // Configurable font for all module text/icons (bar.font).
            property string fontFamily: "Hack Nerd Font"
            // Alpha used by the optional full-bar background strip (bar.barOpacity).
            property real barOpacity: 0.85
            // Master switch for live island drag & drop (bar.dragModules).
            property bool dragModulesEnabled: true
            // Flat-mode icon tinting for the classic engine (solid/fill styles):
            // when true, ModulePill tints its content with the module accent
            // color instead of filling an island (no double fill on a strip).
            property bool accentTintMode: false
            // Clock format used while the classic engine is active (classicbar.timeFormat).
            property string classicTimeFormat: "" 
            // Tracks the last applied orientation: an axis change (horizontal ↔
            // vertical) remounts the zones in-process (Phase D3) so every module
            // re-reads bar.orientation at creation — no full shell reload.
            property string _lastOrientation: ""

            // ================================================================
            // DUAL BAR ENGINES (Phase D4-E1b): "bar" ⇄ "classic"
            //
            // The same window hosts two render engines. In engine "classic" the
            // classic left/center/right bar (bar/ClassicBar.qml) is mounted
            // instead of the zone Repeater, driven by settings.json's top-level
            // "classicbar" key (see BarLayout.js classicbar section). No data is
            // duplicated and no "bar" settings are written: while classicMode the
            // host simply applies the classic style's visual flags (pillBg/
            // pillSolid/barBg/edgeGap via classicStyleFlags()) + the classicbar
            // position onto ITSELF; modules only see the standard contract, so
            // they behave identically in both engines. Switching back to
            // "bar" restores the persisted barConfig through syncBarConfig().
            // ================================================================
            property string barEngine: "bar"
            property var classicConfig: BarLayout.classicbarDefaults()
            // Revealed state of the optional classic autohide (ClassicBar drives it
            // through the bar object; the exclusiveZone binding reacts to it).
            property bool classicAutohideRevealed: true
            readonly property bool classicMode: barWindow.barEngine === "classic"
            // Fill forces widthPercent to 100 (BarLayout.isFillStyle) — the
            // strip then spans the whole content frame edge-to-edge.
            readonly property bool classicFillStyle: barWindow.classicMode && BarLayout.isFillStyle(barWindow.classicConfig.style)
            // The strip/tab sits flush against the screen edge: fill always,
            // autohide bars need the flush edge so the 5px reveal tab is at the
            // very screen edge (the ClassicBar translate leaves only that sliver).
            readonly property bool classicEdgeFlush: barWindow.classicMode && (barWindow.classicFillStyle || barWindow.classicConfig.autohide === true)
            // ClassicBar's content box (the strip band + sections). The click
            // mask follows this item's geometry (see the Region above).
            property Item classicAreaItem: classicLoader.item ? classicLoader.item.classicContentArea : null
            // Content choke point for the settings reader: text of the last
            // successfully parsed settings.json. Keeps the directory watcher's
            // wakeups on unrelated config files completely silent.
            property string lastSettingsJson: ""

            // ================================================================
            // LIVE ISLAND DRAG & DROP STATE (Phase D2)
            // ================================================================
            property bool dragBusy: false
            // Set right before a dragged island is released so the propagated
            // release cannot fire the pill's own click (see Zone slotDragArea).
            property bool consumeNextModuleClick: false
            property string dragId: ""
            property var dragStartBar: ({})
            property var dragWorkingBar: ({})
            property bool pendingBarConfigRefresh: false
            // Set when an axis flip arrived while a drag owned the config; the
            // remount then runs at the end of the gesture instead (see
            // endDragAt/cancelDrag).
            property bool pendingAxisRemount: false
            // Same deferral for engine/config switches that affect the classic
            // visuals (barEngine/classicConfig/position flips mid-drag).
            property bool pendingClassicRefresh: false
            // Orientation the currently mounted ClassicBar was created with
            // ("" = nothing mounted yet). Classic modules bake compact/horizontal
            // branches at creation exactly like bar zones, so an axis flip
            // must recreate the ClassicBar loader (see syncClassicLoader()).
            property string _classicOrientation: ""

            // Begin a drag session for module `id` (called by Zone slots).
            function startDrag(id) {
                if (barWindow.dragBusy || !barWindow.dragModulesEnabled) return;
                if (!barWindow.barConfig || !BarLayout.isList(barWindow.barConfig.zones)) return;
                try {
                    barWindow.dragStartBar = BarLayout.cloneBar(barWindow.barConfig);
                    barWindow.dragWorkingBar = BarLayout.cloneBar(barWindow.barConfig);
                } catch (e) { return; }
                barWindow.dragId = id;
                barWindow.dragBusy = true;
                barWindow.pendingBarConfigRefresh = false;
            }

            // Live reorder under the pointer (throttled). `px/py` are in this
            // window's coordinates.
            function updateDragAt(px, py) {
                if (!barWindow.dragBusy) return;
                let hit = null;
                let zones = barContent.children;
                for (let i = 0; i < zones.length; i++) {
                    let z = zones[i];
                    if (!z || !z.isBarZone) continue;
                    if (z.containsBarPoint(px, py)) {
                        hit = z.barPointToInsert(px, py);
                        if (hit) break;
                    }
                }
                if (!hit) return; // pointer not over any zone: keep last spot
                let next = BarLayout.moduleMoveTo(barWindow.dragWorkingBar, barWindow.dragId, hit.zoneId, hit.index);
                let nextStr = JSON.stringify(next);
                if (nextStr !== JSON.stringify(barWindow.barConfig)) {
                    barWindow.dragWorkingBar = next;
                    barWindow.barConfig = next;
                }
            }

            // Commit (drop inside a zone) or cancel (drop outside the bar).
            function endDragAt(px, py) {
                if (!barWindow.dragBusy) return;
                let inside = false;
                let zones = barContent.children;
                for (let i = 0; i < zones.length; i++) {
                    let z = zones[i];
                    if (z && z.isBarZone && z.containsBarPoint(px, py)) { inside = true; break; }
                }
                let finalBar = barWindow.dragWorkingBar;
                barWindow.dragBusy = false;
                barWindow.dragId = "";
                if (inside) {
                    // Write once, atomically; the in-memory config is already the
                    // result, so the watcher sees no diff and nothing flickers.
                    Config.setSetting("bar", finalBar);
                } else {
                    barWindow.barConfig = barWindow.dragStartBar;
                }
                if (barWindow.pendingBarConfigRefresh) {
                    barWindow.pendingBarConfigRefresh = false;
                    settingsReader.running = false;
                    settingsReader.running = true;
                }
                // An axis flip that arrived mid-drag remounts now that the
                // gesture no longer owns the config.
                barWindow.flushPendingAxisRemount();
                // Same for classic engine/config switches deferred mid-drag.
                barWindow.flushPendingClassicRefresh();
            }

            // Abort the session (drag cancelled by the slot MouseArea).
            function cancelDrag() {
                if (!barWindow.dragBusy) return;
                let restore = barWindow.dragStartBar;
                barWindow.dragBusy = false;
                barWindow.dragId = "";
                barWindow.barConfig = restore;
                if (barWindow.pendingBarConfigRefresh) {
                    barWindow.pendingBarConfigRefresh = false;
                    settingsReader.running = false;
                    settingsReader.running = true;
                }
                barWindow.flushPendingAxisRemount();
                barWindow.flushPendingClassicRefresh();
            }

            // Rebuild every zone delegate in THIS process (Phase D3). Crossing
            // the axis used to IPC-reload the whole shell because modules baked
            // stale orientation state at creation. Emptying the zones model
            // destroys each Zone + its module Loaders, and Qt.callLater refills
            // it from the already-synced barConfig in the next event turn, so
            // fresh modules read the NEW orientation/geometry from the start.
            // syncBarConfig() (geometry, margins, anchors) already ran before
            // this is called, so the window relayouts and the zones mount
            // against the final values. Zone's entrance cascade replays because
            // the new delegates start with ready=false.
            function remountZones() {
                if (!barWindow.configReady) return;
                barWindow.zones = [];
                Qt.callLater(() => {
                    let z = (barWindow.barConfig && barWindow.barConfig.zones)
                          ? barWindow.barConfig.zones : [];
                    barWindow.zones = z;
                });
            }

            // Run a deferred remount after a drag gesture ends (axis flips are
            // impossible mid-drag, but the guard keeps the invariant anyway).
            function flushPendingAxisRemount() {
                if (!barWindow.pendingAxisRemount) return;
                barWindow.pendingAxisRemount = false;
                barWindow.remountZones();
            }

            // Deferred classic-visual refresh after a drag gesture ends.
            function flushPendingClassicRefresh() {
                if (!barWindow.pendingClassicRefresh) return;
                barWindow.pendingClassicRefresh = false;
                barWindow.syncVisualEngine();
            }

            // ---- dual engine: visuals ---------------------------------------
            // In classic mode the host overrides ITS OWN visual flags with the
            // ones derived from the classicbar style, plus the classicbar position
            // (the classicbar owns the screen edge while active). Nothing is ever
            // written back into settings.json's "bar" key — syncBarConfig()
            // restores the persisted values when the engine switches back.
            function applyClassicVisuals() {
                if (!barWindow.classicMode || !barWindow.barConfig) return;
                let f = BarLayout.classicStyleFlags(barWindow.classicConfig.style);
                if (f.pillBg !== undefined) barWindow.pillBg = f.pillBg;
                if (f.pillSolid !== undefined) barWindow.pillSolid = f.pillSolid;
                if (f.barBg !== undefined) barWindow.barBg = f.barBg;
                if (f.edgeGap !== undefined) barWindow.edgeGap = f.edgeGap;
                // Distinct pills (classicantium BarTab, shown for modular + solid):
                // island fills become SOLID so each pill reads clearly even in
                // modular; on the strip the ClassicBar draws the raised slabs.
                if (barWindow.classicConfig.distinctPills === true) barWindow.pillSolid = true;
                // Classicantium corners follow the theme radius; ours is a knob
                // (classicbar.roundness) mapped onto the shared pillRadius() so
                // islands/strip/groups stay in sync. Restored on engine exit.
                barWindow.roundness = (typeof barWindow.classicConfig.roundness === "number")
                    ? barWindow.classicConfig.roundness : barWindow.roundness;
                // Time format for the clock island (bar engine keeps HH:mm:ss).
                if (typeof barWindow.classicConfig.timeFormat === "string"
                    && barWindow.classicConfig.timeFormat !== ""
                    && barWindow.classicTimeFormat !== barWindow.classicConfig.timeFormat) {
                    barWindow.classicTimeFormat = barWindow.classicConfig.timeFormat;
                }
                // classicbar.position is normalized (POSITIONS) by getClassicbar().
                if (barWindow.position !== barWindow.classicConfig.position) {
                    barWindow.position = barWindow.classicConfig.position;
                    // orientation is a plain property (kept in sync manually,
                    // see syncBarConfig) — never a derived binding.
                    barWindow.orientation = (barWindow.position === "top" || barWindow.position === "bottom") ? "horizontal" : "vertical";
                }
                barWindow.accentTintMode = barWindow.classicConfig.style !== "modular";
                // ---- Phase R1: classicbar visual keys (classicantium BarTab parity) ----
                // These live on the host while the classic engine renders and are
                // restored by syncBarConfig() when the engine leaves "classic":
                //   • edgeGap: classicantium floats its bar s(4) off the screen edge
                //     in every non-fill style (Bar.qml:265-270 margins s(4)); the
                //     bar's default 8px edge breathing would read differently on
                //     the classic bar. Style flags may still force 0 (fill).
                //   • thickness: classicbar.thickness (px) overrides the band size;
                //     null = keep the bar's own thickness (inherit).
                //   • barOpacity: classicbar.opacity (percent) → strip alpha; the
                //     strip reads bar.barOpacity only (see ClassicBar.qml), so a
                //     leftover bar pillSolid:true can never freeze it opaque.
                barWindow.edgeGap = (f.edgeGap !== undefined) ? f.edgeGap : 4;
                if (typeof barWindow.classicConfig.thickness === "number") {
                    barWindow.thickness = Math.max(24, Math.min(120, barWindow.classicConfig.thickness));
                }
                if (typeof barWindow.classicConfig.opacity === "number") {
                    barWindow.barOpacity = Math.max(0.2, Math.min(1.0, barWindow.classicConfig.opacity / 100));
                }
                // Config/engine edits always re-reveal (never leave the bar
                // hidden behind a fresh config).
                barWindow.classicAutohideRevealed = true;
            }

            // Re-apply whichever engine owns the window visuals right now:
            // classic → classic flags/position; bar → the persisted barConfig.
            // Visual-only: zones are never touched here. Deferred while a drag
            // owns the config (same pattern as the axis remount).
            function syncVisualEngine() {
                if (!barWindow.configReady) return;
                if (barWindow.dragBusy) { barWindow.pendingClassicRefresh = true; return; }
                if (barWindow.classicMode) barWindow.applyClassicVisuals();
                else barWindow.syncBarConfig();
                barWindow.syncClassicLoader();
            }

            // Mount/unmount the ClassicBar loader (engine switch) or recreate it
            // when the axis flipped while classic mode was active (classic modules
            // bake compact/horizontal branches at creation, exactly like bar
            // zones do — hence the same in-process remount approach).
            //
            // Robust mount contract: the loader is driven by STATE (engine +
            // configReady), not by one-shot event ordering. We mount whenever
            // the item is missing and retry a few times at boot, because the
            // reader pass that flips the engine may race the very first
            // request. A null item here means NO bar at all, so never leave
            // it half-mounted.
            function syncClassicLoader() {
                if (!barWindow.configReady) return;
                let want = barWindow.classicMode;
                let item = classicLoader.item;
                if (want) {
                    let axisFlip = barWindow._classicOrientation !== "" && barWindow._classicOrientation !== barWindow.orientation;
                    if (!item || classicLoader.status !== Loader.Ready || axisFlip) {
                        classicLoader.setSource("ClassicBar.qml", classicLoader.classicInitialProps());
                        barWindow._classicOrientation = barWindow.orientation;
                    }
                } else if (classicLoader.source !== "") {
                    classicLoader.source = "";
                    barWindow._classicOrientation = "";
                }
            }
            // Boot/late-config safety: reader passes and handlers can fire out
            // of order (engine flips right after configReady). Re-check the
            // loader a few times after startup until it is actually mounted.
            Timer {
                id: classicMountGuard
                interval: 400
                repeat: true
                running: barWindow.classicMode && barWindow.configReady
                property int ticks: 0
                onTriggered: {
                    if (!classicLoader.item || classicLoader.status !== Loader.Ready) barWindow.syncClassicLoader();
                    ticks++;
                    if (classicLoader.item || ticks > 12) running = false;
                }
            }
            onBarConfigChanged: {
                // syncBarConfig() applies the PERSISTED bar values; while the
                // classic engine is active the classic visuals/position override them
                // right after (restored automatically when engine === "bar").
                syncBarConfig();
                if (barWindow.classicMode) barWindow.applyClassicVisuals();
                // Only remount on an ACTUAL axis change (vertical ↔ horizontal),
                // and never during boot (before configReady). Same-axis position
                // moves and pure visual changes never rebuild anything. The
                // orientation is read AFTER the classic override above so classic-side
                // flips are caught by the same detector.
                let axisFlip = barWindow.configReady && barWindow._lastOrientation !== "" && barWindow.orientation !== barWindow._lastOrientation;
                if (axisFlip) {
                    if (barWindow.classicMode) {
                        if (barWindow.dragBusy) barWindow.pendingClassicRefresh = true;
                        else barWindow.syncClassicLoader();
                    } else if (barWindow.dragBusy) {
                        barWindow.pendingAxisRemount = true;
                    } else {
                        barWindow.remountZones();
                    }
                }
                barWindow._lastOrientation = barWindow.orientation;
            }
            // Engine switch ("bar" ⇄ "classic") and classicbar edits re-run the
            // visual pass without touching zones. When the engine returns to
            // "bar", syncVisualEngine() restores the persisted barConfig.
            onBarEngineChanged: barWindow.syncVisualEngine()
            onClassicConfigChanged: barWindow.syncVisualEngine()
            // ClassicBar modules bake compact/horizontal branches at creation;
            // remount the bar loader on axis flips in classic mode (see
            // syncClassicLoader). Bar-mode flips keep using the zone remount
            // path above.
            onOrientationChanged: {
                if (!barWindow.classicMode || !barWindow.configReady) return;
                if (barWindow.dragBusy) { barWindow.pendingClassicRefresh = true; return; }
                barWindow.syncClassicLoader();
            }
            Component.onCompleted: {
                syncBarConfig();
                barWindow._lastOrientation = barWindow.orientation;
                // Keep Hyprland window-border colors in sync with the palette /
                // border overrides at all times (the bar bar is always alive,
                // so this fires whether or not the BarEditor is open).
                barColors.paletteApplied.connect(function() { barColors.syncWindowBorders(); });
                barColors.settingsUpdated.connect(function() { barColors.syncWindowBorders(); });
            }

            function syncBarConfig() {
                if (!barConfig) return;
                barWindow.position = barConfig.position || "top";
                barWindow.orientation = (barWindow.position === "top" || barWindow.position === "bottom") ? "horizontal" : "vertical";
                barWindow.paletteName = barConfig.palette || "x";
                barWindow.thickness = barConfig.thickness;
                barWindow.edgeGap = barConfig.edgeGap;
                barWindow.roundness = barConfig.roundness;
                barWindow.pillBg = barConfig.pillBg;
                barWindow.pillSolid = barConfig.pillSolid;
                barWindow.barBg = barConfig.barBg;
                barWindow.barOpacity = (typeof barConfig.barOpacity === "number") ? barConfig.barOpacity : 0.85;
                barWindow.dragModulesEnabled = barConfig.dragModules !== false;
                barWindow.accentTintMode = false;
                barWindow.workspacesMarker = (typeof barConfig.workspacesMarker === "string") ? barConfig.workspacesMarker : "number";
                barWindow.workspacesMarkerText = (typeof barConfig.workspacesMarkerText === "string") ? barConfig.workspacesMarkerText : "";
                barWindow.borderWidth = barConfig.borderWidth;
                barWindow.borderColor = barConfig.borderColor;
                barWindow.fontFamily = barConfig.font || "Hack Nerd Font";
                barWindow.zones = barConfig.zones;
                applyPosition();
            }

            // Legacy aliases so pre-ModulePill modules keep working unchanged.
            property real topbarRoundness: roundness
            property bool topbarPillBg: pillBg
            property bool topbarPillSolid: pillSolid
            onRoundnessChanged: topbarRoundness = roundness
            onPillBgChanged: topbarPillBg = pillBg
            onPillSolidChanged: topbarPillSolid = pillSolid

            // ================================================================
            // GEOMETRY
            // ================================================================
            property int barHeight: s(thickness)
            // Vertical bars need extra width (~50px physical) to fit compact
            // islands and the HH:mm clock comfortably.
            property int barWidth: orientation === "horizontal" ? s(thickness) : Math.max(s(thickness), s(70))
            property int pillHeight: orientation === "horizontal" ? barHeight - s(12) : barWidth - s(8)
            property int pillWidth: orientation === "horizontal" ? barHeight - s(12) : barWidth - s(8)
            function pillRadius(h) { return Math.round(h * 0.5 * roundness); }

            implicitHeight: orientation === "horizontal" ? barHeight : (barWindow.screen ? barWindow.screen.height : 1080)
            implicitWidth: orientation === "horizontal" ? (barWindow.screen ? barWindow.screen.width : 1920) : barWidth

            // --- margins -------------------------------------------------------
            // The bar margins offset the whole surface from the anchored edges:
            // the screen-edge side carries edgeGap, the other sides s(4). While
            // the classic engine is active the values above are overridden:
            //   • fill:        EVERY margin is 0 — classicantium's fill reaches all
            //                  four screen edges (Bar.qml:265-270 margins 0 when
            //                  isFill). WidthPercent is forced to 100 so the
            //                  strip truly spans the whole screen.
            //   • autohide:    the edge side is 0 too, so the 4px reveal sliver
            //                  that ClassicBar leaves after the hide translate sits
            //                  flush at the very screen edge;
            //   • edge side:   s(4) in every other classic state (applyClassicVisuals
            //                  overrides edgeGap to 4 — classicantium margins s(4));
            //   • cross sides (left/right on top/bottom bars and vice versa)
            //                  keep their s(4) — identical to classicantium.
            // Everything restores itself on the way back to the bar engine
            // because the expressions below fall through to the bar formula.
            margins {
                top: orientation === "vertical"
                    ? (barWindow.classicMode && barWindow.classicFillStyle ? 0 : s(4))
                    : (barWindow.classicMode
                        ? (position === "top" ? (barWindow.classicEdgeFlush ? 0 : s(edgeGap))
                            : (position === "bottom" && barWindow.classicFillStyle ? 0 : s(4)))
                        : (position === "top" ? s(edgeGap) : s(4)))
                bottom: orientation === "vertical"
                    ? (barWindow.classicMode && barWindow.classicFillStyle ? 0 : s(4))
                    : (barWindow.classicMode
                        ? (position === "bottom" ? (barWindow.classicEdgeFlush ? 0 : s(edgeGap))
                            : (position === "top" && barWindow.classicFillStyle ? 0 : s(4)))
                        : (position === "bottom" ? s(edgeGap) : s(4)))
                left: orientation === "horizontal"
                    ? (barWindow.classicMode && barWindow.classicFillStyle ? 0 : s(4))
                    : (barWindow.classicMode
                        ? (position === "left" ? (barWindow.classicEdgeFlush ? 0 : s(edgeGap))
                            : (position === "right" && barWindow.classicFillStyle ? 0 : s(4)))
                        : (position === "left" ? s(edgeGap) : s(4)))
                right: orientation === "horizontal"
                    ? (barWindow.classicMode && barWindow.classicFillStyle ? 0 : s(4))
                    : (barWindow.classicMode
                        ? (position === "right" ? (barWindow.classicEdgeFlush ? 0 : s(edgeGap))
                            : (position === "left" && barWindow.classicFillStyle ? 0 : s(4)))
                        : (position === "right" ? s(edgeGap) : s(4)))
            }
            // A hidden autohide bar reserves no edge space at all; every other
            // state reserves the same band as the bar engine.
            exclusiveZone: barWindow.classicMode && barWindow.classicConfig.autohide === true && !barWindow.classicAutohideRevealed
                ? 0
                : (orientation === "horizontal" ? barHeight : barWidth)
            color: "transparent"
            
            // --- clickthrough mask (classic engine) --------------------------------
            // The layer surface spans the whole bar band (or the whole screen
            // width for widthPercent < 100), but only the actual strip band +
            // its contents must be interactive. The mask tracks the ClassicBar
            // content box ITEM (Region.item watches x/y/w/h, so the autohide
            // slide keeps the clickable area glued to the visible strip — when
            // hidden only the 4px tab sliver remains clickable and everything
            // else passes through to the windows below). null in the bar
            // engine keeps today's whole-band input behavior.
            Region {
                id: classicMask
                Region {
                    item: barWindow.classicAreaItem
                }
            }
            mask: barWindow.classicMode && barWindow.classicAreaItem ? classicMask : null

            function applyPosition() {
                barWindow.anchors.top = undefined;
                barWindow.anchors.bottom = undefined;
                barWindow.anchors.left = undefined;
                barWindow.anchors.right = undefined;
                if (position === "top") { barWindow.anchors.top = true; barWindow.anchors.left = true; barWindow.anchors.right = true; }
                else if (position === "bottom") { barWindow.anchors.bottom = true; barWindow.anchors.left = true; barWindow.anchors.right = true; }
                else if (position === "left") { barWindow.anchors.left = true; barWindow.anchors.top = true; barWindow.anchors.bottom = true; }
                else { barWindow.anchors.right = true; barWindow.anchors.top = true; barWindow.anchors.bottom = true; }
            }
            onPositionChanged: applyPosition()

            // ================================================================
            // IPC (same target as before so qs_manager / Config keep working)
            // ================================================================
            IpcHandler {
                target: "topbar"
                function forceReload() { Quickshell.reload(true) }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) Quickshell.reload(true)
                    else barWindow.pendingReload = true
                }
                function reloadColors() { barColors.forceRefresh() }
                function toggleUpdate() { barWindow.forceUpdateShow = !barWindow.forceUpdateShow }
            }

            // ================================================================
            // WIDGET / RECORDING / UPDATE POLLERS
            // ================================================================
            property bool pendingReload: false
            property string activeWidget: ""
            // El panel Settings unificado (bar-editor, SUPER+SHIFT+S/D) sustituye
            // al antiguo popup "settings"; ambos ids cuentan como panel abierto.
            // Solo se usa para diferir reloads y mantener la barra classic visible:
            // el panel nuevo es CENTRADO, así que la barra NO se desplaza.
            property bool isSettingsOpen: activeWidget === "settings" || activeWidget === "bar-editor"
            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
                // Never let the classic bar autohide while the settings panel is
                // open (the popup sits on the same edge the mouse leaves to).
                if (barWindow.isSettingsOpen) barWindow.classicAutohideRevealed = true;
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }
            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }
            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text ? this.text.trim() : "";
                        if (txt === "" || txt === "{}") return;
                        // Choke point (Theme.qml pattern): the directory watcher
                        // below wakes on ANY file event under ~/.config/hypr —
                        // identical settings.json content must not re-apply the
                        // config, reset configReady or replay animations.
                        if (txt === barWindow.lastSettingsJson) return;
                        try {
                            // A live drag owns barConfig; defer external reads
                            // until the gesture finishes (commit/cancel).
                            if (barWindow.dragBusy) {
                                barWindow.pendingBarConfigRefresh = true;
                                return;
                            }
                            let parsed = JSON.parse(txt);
                            barWindow.lastSettingsJson = txt;
                            let next = BarLayout.getBar(parsed);
                            if (JSON.stringify(next) !== JSON.stringify(barWindow.barConfig)) {
                                barWindow.barConfig = next;
                            }
                            if (parsed.uiScale !== undefined && barWindow.uiScale !== parsed.uiScale) {
                                barWindow.uiScale = parsed.uiScale;
                            }
                            if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                barWindow.showHelpIcon = parsed.topbarHelpIcon;
                            }
                            if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                barWindow.workspaceCount = parsed.workspaceCount;
                                wsDaemon.running = false;
                                wsDaemon.running = true;
                            }
                            // uiScale + barConfig are now final: safe to build modules.
                            barWindow.configReady = true;
                            // Dual engine: parse the engine switch + classicbar AFTER
                            // the bar config so the classic overrides win when the
                            // engine is "classic". classicConfig is only replaced when
                            // its JSON really changed (avoids a re-render loop
                            // with the compare-based barConfig choke point).
                            let rawEngine = parsed.barEngine === "classic" ? "classic" : "bar";
                            if (barWindow.barEngine !== rawEngine) barWindow.barEngine = rawEngine;
                            let classicNext = BarLayout.getClassicbar(parsed);
                            if (JSON.stringify(classicNext) !== JSON.stringify(barWindow.classicConfig)) {
                                barWindow.classicConfig = classicNext;
                            }
                            // First boot: barEngine/classicConfig handlers above ran
                            // before configReady was true, so run the visual
                            // sync + ClassicBar mount explicitly now.
                            barWindow.syncVisualEngine();
                        } catch (e) {}
                    }
                }
            }
            // FileView watch (no shell processes, reload-safe): settings.json
            // is written atomically (tmp + mv), and FileView follows the file
            // across renames — unlike an inotify watch on the inode. On any
            // change the cat-based reader re-runs; identical content is choked
            // in the reader (lastSettingsJson) so unrelated edits stay silent.
            FileView {
                id: settingsWatcher
                path: Quickshell.env("HOME") + "/.config/hypr/settings.json"
                watchChanges: true
                onFileChanged: {
                    if (barWindow.dragBusy) {
                        barWindow.pendingBarConfigRefresh = true;
                        return;
                    }
                    settingsReader.running = false;
                    settingsReader.running = true;
                }
            }

            // ================================================================
            // SYSTEM STATE
            // ================================================================
            property bool showHelpIcon: true
            property bool isRecording: false
            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow
            property int workspaceCount: 8
            // Empty-workspace marker for the Workspaces module
            // (number|dot|letter|custom) + optional custom character.
            property string workspacesMarker: "number"
            property string workspacesMarkerText: "" 

            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            property bool fastPollerLoaded: false
            property bool isDataReady: false
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }

            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: colors.yellow

            // --- focused window (FocusModule) -------------------------------------
            property string focusTitle: ""
            property string focusClass: ""
            property string focusIcon: "󰋼"
            readonly property bool hasFocus: barWindow.focusTitle !== ""

            // Map common WM_CLASS values to Nerd Font glyphs so the focus island
            // shows a recognizable app icon without spawning any extra process.
            function focusIconForClass(cls) {
                const c = String(cls || "").toLowerCase();
                const icons = {
                    "firefox": "󰈹", "librewolf": "󰈹", "zen": "󰈹",
                    "google-chrome": "󰈹", "chromium": "󰈹", "brave": "󰈹",
                    "kitty": "󰄛", "alacritty": "󰄛", "ghostty": "󰄛", "konsole": "󰄛", "wezterm": "󰄛", "xterm": "󰄛",
                    "code": "󰨞", "codium": "󰨞", "code-oss": "󰨞",
                    "spotify": "󰓇", "discord": "󰙯", "vesktop": "󰙯",
                    "nautilus": "󰉋", "dolphin": "󰉋", "thunar": "󰉋", "nemo": "󰉋",
                    "obsidian": "󰠮", "zathura": "󰈇", "org.gnome.nautilus": "󰉋"
                };
                return icons[c] || "󰋼";
            }

            property string cpuPercent: "--"
            property string ramPercent: "--"
            property bool sysDataReady: false

            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            property string kbLayout: "us"

            ListModel {
                id: workspacesModel
                property int activeIndex: 0
            }
            readonly property var wsModel: workspacesModel
            function refreshMusic() { musicForceRefresh.running = true; }

            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }
            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""
            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            property color batDynamicColor: {
                if (isCharging) return colors.green;
                if (batCap <= 20) return colors.red;
                return colors.text;
            }

            // ================================================================
            // WORKSPACES
            // ================================================================
            Process {
                id: wsDaemon
                command: Compositor.workspacesCommand
                running: true
            }
            Process {
                id: wsReader
                running: true
                command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let newData = JSON.parse(txt);
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "", "wsClasses": "" });
                                }
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }
                                let newActive = -1;
                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;
                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                    if (newData[i].classes != undefined && workspacesModel.get(i).wsClasses !== newData[i].classes) {
                                        workspacesModel.setProperty(i, "wsClasses", newData[i].classes);
                                    }
                                }
                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }
                            } catch(e) {}
                        }
                    }
                }
            }
            // FileView watch on the workspaces JSON (process-free, follows
            // atomic rewrites). Reload-safe: no shell children to orphan.
            FileView {
                id: wsWatcher
                path: barWindow.paths.getRunDir("workspaces") + "/workspaces.json"
                watchChanges: true
                onFileChanged: {
                    wsReader.running = false;
                    wsReader.running = true;
                }
            }
            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }
            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;
                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;
                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);
                    let posSecs = (posParts.length === 3)
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2])
                        : (posParts[0] * 60 + posParts[1]);
                    let lenSecs = (lenParts.length === 3)
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2])
                        : (lenParts[0] * 60 + lenParts[1]);
                    if (isNaN(posSecs) || isNaN(lenSecs)) return;
                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;
                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }
                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    barWindow.musicData = newData;
                }
            }
            Process {
                id: kbPoller; running: true
                command: Compositor.keyboardCommand
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.kbLayout !== txt) barWindow.kbLayout = txt;
                        barWindow.fastPollerLoaded = true;
                    }
                }
            }


            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/audio_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                    }
                }
            }


            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                    }
                }
            }


            Process {
                id: btPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                    }
                }
            }


            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newBat = data.percent.toString() + "%";
                                if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                if (barWindow.batIcon !== data.icon) barWindow.batIcon = data.icon;
                                if (barWindow.batStatus !== data.status) barWindow.batStatus = data.status;
                            } catch(e) {}
                        }
                    }
                }
            }



            // ================================================================
            // POLLING TIMERS (process-free refresh)
            // ================================================================
            // The old fetch+wait/process watchers leaked long-running children
            // across in-process reloads (orphans exhausted inotify/process
            // limits). Polling Timers keep the same data fresh with zero
            // long-running processes.
            Timer { id: kbPollTimer; interval: 2000; running: true; repeat: true; onTriggered: { kbPoller.running = false; kbPoller.running = true; } }
            Timer { id: audioPollTimer; interval: 2000; running: true; repeat: true; onTriggered: { audioPoller.running = false; audioPoller.running = true; } }
            Timer { id: netPollTimer; interval: 3000; running: true; repeat: true; onTriggered: { networkPoller.running = false; networkPoller.running = true; } }
            Timer { id: btPollTimer; interval: 4000; running: true; repeat: true; onTriggered: { btPoller.running = false; btPoller.running = true; } }
            Timer { id: batPollTimer; interval: 3000; running: true; repeat: true; onTriggered: { batteryPoller.running = false; batteryPoller.running = true; } }
            Timer { id: recPollTimer; interval: 2500; running: true; repeat: true; onTriggered: { recPoller.running = false; recPoller.running = true; } }
            Timer { id: updatePollTimer; interval: 4000; running: true; repeat: true; onTriggered: { updatePoller.running = false; updatePoller.running = true; } }
            Timer { id: musicPollTimer; interval: 3000; running: true; repeat: true; onTriggered: { musicForceRefresh.running = false; musicForceRefresh.running = true; } }
            Timer { id: wsPollTimer; interval: 1500; running: true; repeat: true; onTriggered: { wsReader.running = false; wsReader.running = true; } }

            // ================================================================
            // WEATHER
            // ================================================================
            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || colors.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }

            // ================================================================
            // FOCUSED WINDOW (FocusModule)
            // ================================================================
            Process {
                id: focusPoller
                command: Compositor.focusCommand
                stdout: StdioCollector {
                    onStreamFinished: {
                        let line = this.text.trim();
                        if (line === "") {
                            if (barWindow.focusTitle !== "") barWindow.focusTitle = "";
                            if (barWindow.focusClass !== "") barWindow.focusClass = "";
                            if (barWindow.focusIcon !== "󰋼") barWindow.focusIcon = "󰋼";
                            return;
                        }
                        let nl = line.indexOf("\n");
                        let cls = nl !== -1 ? line.substring(0, nl) : line;
                        let title = nl !== -1 ? line.substring(nl + 1).trim() : "";
                        if (title === "") title = cls;
                        if (barWindow.focusClass !== cls) {
                            barWindow.focusClass = cls;
                            barWindow.focusIcon = barWindow.focusIconForClass(cls);
                        }
                        if (barWindow.focusTitle !== title) barWindow.focusTitle = title;
                    }
                }
            }
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: { focusPoller.running = false; focusPoller.running = true; }
            }

            // ================================================================
            // SYSTEM MONITOR
            // ================================================================
            Process {
                id: sysmonPoller; running: true
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/system-monitor/fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0) {
                                let d = JSON.parse(this.text.trim());
                                barWindow.cpuPercent = (d.cpu || 0) + "%";
                                barWindow.ramPercent = (d.ram_pct || 0) + "%";
                                barWindow.sysDataReady = true;
                            }
                        } catch(e) {}
                    }
                }
            }
            Timer { interval: 8000; running: true; repeat: true; triggeredOnStart: false; onTriggered: { sysmonPoller.running = false; sysmonPoller.running = true; } }

            // ================================================================
            // CLOCK + TYPEWRITER DATE
            // ================================================================
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    let fmt = barWindow.classicMode && barWindow.classicTimeFormat !== "" ? barWindow.classicTimeFormat : "HH:mm:ss";
                    barWindow.timeStr = Qt.formatDateTime(d, fmt);
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }
            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            // ================================================================
            // ZONES
            // ================================================================

            // Bar background strip (bar.barBg): a solid/translucent band behind
            // the whole bar with only the inner corners rounded, so the islands
            // float INSIDE it like a taskbar. Pill backgrounds then go transparent
            // (see ModulePill) and the accent islands stay as colored pills.
            // Hidden while the classic engine renders (ClassicBar draws its own strip).
            Rectangle {
                id: barBackground
                anchors.fill: parent
                visible: barWindow.barBg && !barWindow.classicMode
                radius: barWindow.pillRadius(barWindow.pillHeight)
                topLeftRadius: orientation === "vertical" ? 0 : (position === "top" ? 0 : radius)
                topRightRadius: orientation === "vertical" ? 0 : (position === "top" ? 0 : radius)
                bottomLeftRadius: orientation === "vertical" ? 0 : (position === "bottom" ? 0 : radius)
                bottomRightRadius: orientation === "vertical" ? 0 : (position === "bottom" ? 0 : radius)
                // vertical: flat on the screen-edge side
                color: Qt.rgba(barColors.base.r, barColors.base.g, barColors.base.b, barWindow.pillSolid ? 1.0 : barWindow.barOpacity)
                border.width: barWindow.borderWidth
                border.color: barColors[borderColor] || barColors.surface1
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Item {
                id: barContent
                anchors.fill: parent

                // Zones only build once uiScale/baseScale are final (bar.s() is a
                // function, so modules can't reactively rescale after creation).
                visible: barWindow.configReady
                Repeater {
                    // Engine gate: the zone engine only mounts in bar mode. The
                    // empty model destroys every Zone + module Loader while the
                    // classic engine renders (same in-process remount idea as the
                    // axis flip); flipping back recreates them against the still
                    // synced barConfig.
                    model: barWindow.classicMode ? [] : barWindow.zones
                    delegate: Zone {
                        required property var modelData
                        required property int index
                        bar: barWindow
                        colors: barWindow.colors
                        zoneData: modelData
                        zoneIndex: index
                    }
                }

                // Classic left/center/right engine (Phase D4-E1b). Mounted only
                // in classic mode; the loaded ClassicBar is recreated on engine/axis
                // changes through syncClassicLoader().
                Loader {
                    id: classicLoader
                    anchors.fill: parent
                    // Initial properties for the ClassicBar root (required props);
                    // classicConfig is bound live so settings hot-reloads reach the
                    // loaded bar without remounting it.
                    function classicInitialProps() {
                        return {
                            "bar": barWindow,
                            "colors": barWindow.colors,
                            "classicConfig": Qt.binding(() => barWindow.classicConfig)
                        };
                    }
                }
            }
        }
    }
}
