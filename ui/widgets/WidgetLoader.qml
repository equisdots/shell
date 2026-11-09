import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"

// ============================================================================
// WidgetLoader — per-screen manager of desktop widgets (Phase W3).
//
// Owns the ListModel of widgets for ONE screen and an Instantiator that
// materializes a Widget (PanelWindow) per row. Persists the layout to
// ~/.local/state/quickshell/widgets/<safeMonitorName>/layout.json with
// atomic writes (tmp + mv) debounced ~300 ms.
//
// The persisted file is the source of truth for geometry. At login Hyprland
// exposes the wildcard bootstrap scale first and restore-monitors.sh applies
// the saved scale a few seconds later; the loader therefore holds the layout
// (bounded) until it fits the live screen, and re-derives clamped values from
// the raw file on later geometry changes. Automatic clamps are never saved.
//
// The bus (WidgetSync singleton) dispatches redactor commands to the loader
// whose screen matches; this loader also answers redactor queries
// (redactorInfo / layoutForRedactor).
// ============================================================================

Item {
    id: loaderRoot

    required property var screen
    // Shared WidgetRegistry catalog (provided by widgets/Widgets.qml).
    property var registry: null

    // --- screen identity -------------------------------------------------------
    readonly property string monitorName: {
        if (loaderRoot.screen) {
            if (loaderRoot.screen.name && loaderRoot.screen.name !== "") return loaderRoot.screen.name;
            if (loaderRoot.screen.model && loaderRoot.screen.model !== "") return loaderRoot.screen.model;
        }
        return "default";
    }
    readonly property string safeMonitorName: monitorName.replace(/[^a-zA-Z0-9_-]/g, "_")
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell/widgets/" + loaderRoot.safeMonitorName
    readonly property string stateFile: loaderRoot.stateDir + "/layout.json"

    // Raw layout as persisted on disk: the source of truth for geometry. The
    // model may hold clamped/on-screen values while the compositor is at a
    // different scale than the one the layout was authored at; those
    // display-only values are NEVER written back (a bootstrap scale used to
    // pile every widget up and destroy the saved arrangement).
    property var persistedLayout: []
    property bool layoutLoaded: false
    property bool layoutPending: false
    property double layoutPendingSince: 0

    // Live screen logical size. Hyprland changes it when the monitor scale is
    // applied (monitors.lua wildcard first, restore-monitors.sh shortly after).
    readonly property int screenW: loaderRoot.screen && loaderRoot.screen.width ? loaderRoot.screen.width : 0
    readonly property int screenH: loaderRoot.screen && loaderRoot.screen.height ? loaderRoot.screen.height : 0

    onScreenWChanged: loaderRoot.geometryChanged()
    onScreenHChanged: loaderRoot.geometryChanged()

    property bool isRedacting: false

    function registryOf() {
        if (!loaderRoot.registry) {
            // Standalone fallback: never expected (Widgets.qml injects the
            // shared catalog) but keeps the loader usable in isolation.
            loaderRoot.registry = Qt.createComponent("WidgetRegistry.qml").createObject(loaderRoot);
        }
        return loaderRoot.registry;
    }

    ListModel {
        id: widgetsModel
    }

    // --- serialization helpers ----------------------------------------------------
    function itemToObject(index) {
        let item = widgetsModel.get(index);
        if (!item) return null;
        return {
            id: String(item.wId),
            type: item.wType || "time",
            variant: item.wVariant || registryOf().defaultVariant(item.wType || "time"),
            x: item.wX,
            y: item.wY,
            w: item.wWidth,
            h: item.wHeight,
            opacity: item.wOpacity !== undefined ? item.wOpacity : 1.0,
            rotation: item.wRotation !== undefined && !isNaN(item.wRotation) ? item.wRotation : 0,
            imagePath: item.wImagePath || ""
        };
    }

    // Serializable current list (excludes nothing; model rows are canonical).
    function snapshot() {
        let data = [];
        for (let i = 0; i < widgetsModel.count; i++) {
            let o = loaderRoot.itemToObject(i);
            if (o) data.push(o);
        }
        return data;
    }

    // JSON string of the current layout (consumed by the redactor).
    function layoutForRedactor() {
        return JSON.stringify(loaderRoot.snapshot());
    }

    // Info object the redactor reads: screen identity + current widgets.
    property var redactorInfo: ({
        screenName: loaderRoot.safeMonitorName,
        monitorName: loaderRoot.monitorName,
        widgets: []
    })

    function refreshRedactorInfo() {
        loaderRoot.redactorInfo = {
            screenName: loaderRoot.safeMonitorName,
            monitorName: loaderRoot.monitorName,
            widgets: loaderRoot.snapshot()
        };
    }

    // Model mutated by a user/redactor op: this IS the new persisted intent.
    // Every op* ends in changed(), so this is the single path that schedules
    // persistence — no caller may mutate the model without persisting.
    function changed() {
        loaderRoot.persistedLayout = loaderRoot.snapshot();
        loaderRoot.refreshRedactorInfo();
        WidgetSync.notifyWidgetsChanged();
        loaderRoot.scheduleSave();
    }

    // Notify consumers WITHOUT touching the persisted layout. Used by the
    // load/re-apply paths: automatic clamps for a transient screen size must
    // never overwrite the user's saved arrangement.
    function notifyOnly() {
        loaderRoot.refreshRedactorInfo();
        WidgetSync.notifyWidgetsChanged();
    }

    // --- persistence (atomic write: printf base64 -> tmp, then mv) ----------------
    // saveNow() uses a per-write mktemp file inside the state dir (never a
    // fixed tmp name) so concurrent/torn writes cannot leave a stale tmp that
    // a later write would consume.
    function toBase64(str) {
        let bytes = [];
        for (let i = 0; i < str.length; i++) {
            let code = str.charCodeAt(i);
            if (code < 0x80) bytes.push(code);
            else if (code < 0x800) bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
            else if (code < 0xd800 || code >= 0xe000) bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
            else {
                i++;
                let c = 0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
                bytes.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
            }
        }
        let map = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let out = "";
        for (let i = 0; i < bytes.length; i += 3) {
            let b0 = bytes[i];
            let b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
            let b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
            out += map[b0 >> 2];
            out += map[((b0 & 3) << 4) | (b1 >> 4)];
            out += i + 1 < bytes.length ? map[((b1 & 15) << 2) | (b2 >> 6)] : "=";
            out += i + 2 < bytes.length ? map[b2 & 63] : "=";
        }
        return out;
    }

    function saveNow() {
        saveTimer.stop();
        let jsonStr;
        try {
            jsonStr = JSON.stringify(loaderRoot.snapshot());
        } catch (e) {
            return;
        }
        let b64 = loaderRoot.toBase64(jsonStr);
        let script = "mkdir -p '" + loaderRoot.stateDir + "' && "
            + "tmp=$(mktemp '" + loaderRoot.stateDir + "/layout.json.tmp.XXXXXX') && "
            + "printf '%s' '" + b64 + "' | base64 -d > \"$tmp\" && "
            + "mv -f \"$tmp\" '" + loaderRoot.stateFile + "'";
        Quickshell.execDetached(["bash", "-c", script]);
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: loaderRoot.saveNow()
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    // Bootstrap wait: restore-monitors.sh applies the saved scale a few seconds
    // after hyprland.start. Until then the wildcard rule may expose a different
    // logical size; hold the layout (bounded to 5 s) instead of clamping every
    // widget into the bootstrap resolution.
    Timer {
        id: pendingTimer
        interval: 300
        repeat: true
        onTriggered: loaderRoot.tryApplyLayout()
    }

    // Screen geometry changed after load (scale/mode/hotplug): re-derive the
    // model from the persisted raw layout, never the other way around.
    Timer {
        id: geometryTimer
        interval: 300
        onTriggered: {
            loaderRoot.reapplyPersistedGeometry();
            loaderRoot.notifyOnly();
        }
    }

    function geometryChanged() {
        if (loaderRoot.layoutPending) {
            loaderRoot.tryApplyLayout();
        } else if (loaderRoot.layoutLoaded) {
            geometryTimer.restart();
        }
    }

    function tryApplyLayout() {
        if (!loaderRoot.layoutPending) return;
        if (!loaderRoot.layoutFitsScreen() && (Date.now() - loaderRoot.layoutPendingSince) < 5000)
            return;
        loaderRoot.layoutPending = false;
        pendingTimer.stop();
        loaderRoot.buildModelFromPersisted();
        loaderRoot.layoutLoaded = true;
    }

    // --- model ops (called by the bus / redactor) -----------------------------------
    function uniqueId() {
        return "w_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 0xfffff).toString(36);
    }

    function findIndex(id) {
        let target = String(id);
        for (let i = 0; i < widgetsModel.count; i++) {
            if (String(widgetsModel.get(i).wId) === target) return i;
        }
        return -1;
    }

    function screenWidth() {
        return loaderRoot.screen && loaderRoot.screen.width ? loaderRoot.screen.width : 1920;
    }

    function screenHeight() {
        return loaderRoot.screen && loaderRoot.screen.height ? loaderRoot.screen.height : 1080;
    }

    // --- geometry sanitizer (initial load + opSetGeometry) -------------------------
    // NaN / non-positive numbers fall back to the type default size (or 16 for
    // positions), sizes are clamped to [16 .. screen extent] and positions are
    // clamped so the widget stays fully inside its screen. Fine clamping
    // against the face's declared constraints is done by Widget at render time
    // (Widget.updateEffectiveSize); here we only keep the persisted model
    // values non-degenerate and on-screen.
    function sanitizeGeometry(x, y, w, h, fbW, fbH) {
        let sw = loaderRoot.screenWidth();
        let sh = loaderRoot.screenHeight();
        let num = (v, fallback) => {
            let n = parseFloat(v);
            return isNaN(n) || n <= 0 ? fallback : n;
        };
        let nw = Math.max(16, Math.min(sw, Math.floor(num(w, fbW))));
        let nh = Math.max(16, Math.min(sh, Math.floor(num(h, fbH))));
        let nx = Math.min(Math.max(0, Math.floor(num(x, 16))), Math.max(0, sw - nw));
        let ny = Math.min(Math.max(0, Math.floor(num(y, 16))), Math.max(0, sh - nh));
        return { x: nx, y: ny, w: nw, h: nh };
    }

    // --- persisted-layout helpers ---------------------------------------------------
    function rawValue(item, key, legacy) {
        let v = item[key] !== undefined ? item[key] : item[legacy];
        return parseFloat(v);
    }

    function rawItemFor(id) {
        let target = String(id);
        for (let i = 0; i < loaderRoot.persistedLayout.length; i++) {
            let it = loaderRoot.persistedLayout[i] || {};
            if (String(it.id || it.wId) === target) return it;
        }
        return null;
    }

    // Does the persisted layout fit the live screen? While Hyprland is still
    // at its bootstrap scale (monitors.lua wildcard before restore-monitors.sh
    // applies the saved layout) this is false; the layout then stays pending
    // instead of being clamped into a resolution it was not authored for.
    function layoutFitsScreen() {
        let sw = loaderRoot.screenWidth();
        let sh = loaderRoot.screenHeight();
        let reg = loaderRoot.registryOf();
        for (let i = 0; i < loaderRoot.persistedLayout.length; i++) {
            let it = loaderRoot.persistedLayout[i] || {};
            let type = it.type || it.wType || "time";
            let def = reg.defaultSize(type);
            let num = (v, fb) => {
                let n = parseFloat(v);
                return isNaN(n) || n <= 0 ? fb : n;
            };
            let x = Math.max(0, Math.floor(num(it.x !== undefined ? it.x : it.wX, 16)));
            let y = Math.max(0, Math.floor(num(it.y !== undefined ? it.y : it.wY, 16)));
            let w = Math.max(16, Math.floor(num(it.w !== undefined ? it.w : it.wWidth, def.w)));
            let h = Math.max(16, Math.floor(num(it.h !== undefined ? it.h : it.wHeight, def.h)));
            if (x + w > sw || y + h > sh) return false;
        }
        return true;
    }

    // Re-derive the model geometry from persistedLayout. Used when the screen
    // logical size changes after load (scale/mode/hotplug); it never saves.
    function reapplyPersistedGeometry() {
        if (loaderRoot.persistedLayout.length === 0) return;
        let reg = loaderRoot.registryOf();
        for (let i = 0; i < widgetsModel.count; i++) {
            let row = widgetsModel.get(i);
            let it = loaderRoot.rawItemFor(row.wId);
            if (!it) continue;
            let def = reg.defaultSize(row.wType || it.type || it.wType || "time");
            let g = loaderRoot.sanitizeGeometry(
                loaderRoot.rawValue(it, "x", "wX"),
                loaderRoot.rawValue(it, "y", "wY"),
                loaderRoot.rawValue(it, "w", "wWidth"),
                loaderRoot.rawValue(it, "h", "wHeight"),
                def.w, def.h);
            if (row.wX !== g.x) widgetsModel.setProperty(i, "wX", g.x);
            if (row.wY !== g.y) widgetsModel.setProperty(i, "wY", g.y);
            if (row.wWidth !== g.w) widgetsModel.setProperty(i, "wWidth", g.w);
            if (row.wHeight !== g.h) widgetsModel.setProperty(i, "wHeight", g.h);
        }
    }

    // Rebuild the model from persistedLayout (display-clamped, never saved).
    function buildModelFromPersisted() {
        let data = loaderRoot.persistedLayout;
        let reg = loaderRoot.registryOf();
        widgetsModel.clear();
        for (let i = 0; i < data.length; i++) {
            let item = data[i] || {};
            let itemId = item.id || item.wId;
            if (!itemId) {
                itemId = loaderRoot.uniqueId();
                // Keep the generated id on the raw entry so reapply can match
                // this row; it reaches disk only after the next user edit.
                item.id = String(itemId);
            }
            let type = item.type || item.wType || "time";
            let variant = item.variant || item.wVariant || reg.defaultVariant(type);
            let defSize = reg.defaultSize(type);
            let g = loaderRoot.sanitizeGeometry(
                loaderRoot.rawValue(item, "x", "wX"),
                loaderRoot.rawValue(item, "y", "wY"),
                loaderRoot.rawValue(item, "w", "wWidth"),
                loaderRoot.rawValue(item, "h", "wHeight"),
                defSize.w, defSize.h);
            let op = parseFloat(item.opacity !== undefined ? item.opacity : item.wOpacity);
            if (isNaN(op)) op = 1.0;
            op = Math.max(0.0, Math.min(1.0, op));
            let rot = parseFloat(item.rotation !== undefined ? item.rotation : item.wRotation);
            if (isNaN(rot)) rot = 0;
            widgetsModel.append({
                wId: String(itemId),
                wType: type,
                wVariant: variant,
                wX: g.x,
                wY: g.y,
                wWidth: g.w,
                wHeight: g.h,
                wOpacity: op,
                wRotation: rot,
                wImagePath: String(item.imagePath || item.wImagePath || item.path || "")
            });
        }
        loaderRoot.notifyOnly();
    }

    // Random non-overlapping position for a new widget of the given size.
    function freePosition(w, h, gap) {
        let sw = loaderRoot.screenWidth();
        let sh = loaderRoot.screenHeight();
        let margin = 16;
        gap = gap !== undefined ? gap : 12;
        let maxX = Math.max(margin, sw - w - margin);
        let maxY = Math.max(margin, sh - h - margin);
        let last = { x: margin, y: margin };
        let overlaps = (x, y) => {
            for (let i = 0; i < widgetsModel.count; i++) {
                let o = widgetsModel.get(i);
                if (x < o.wX + o.wWidth + gap && o.wX < x + w + gap
                    && y < o.wY + o.wHeight + gap && o.wY < y + h + gap) return true;
            }
            return false;
        };
        for (let attempt = 0; attempt < 40; attempt++) {
            let x = margin + Math.random() * Math.max(1, maxX - margin);
            let y = margin + Math.random() * Math.max(1, maxY - margin);
            last = { x: Math.round(x), y: Math.round(y) };
            if (!overlaps(last.x, last.y)) return last;
        }
        return last;
    }

    function opAddWidget(type) {
        let reg = loaderRoot.registryOf();
        let def = reg.defaultSize(type);
        let pos = loaderRoot.freePosition(def.w, def.h);
        widgetsModel.append({
            wId: loaderRoot.uniqueId(),
            wType: type,
            wVariant: reg.defaultVariant(type),
            wX: pos.x,
            wY: pos.y,
            wWidth: def.w,
            wHeight: def.h,
            wOpacity: 1.0,
            wRotation: 0,
            wImagePath: ""
        });
        loaderRoot.changed();
    }

    function opRemoveWidget(id) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        widgetsModel.remove(idx, 1);
        loaderRoot.changed();
    }

    function opClearWidgets() {
        if (widgetsModel.count === 0) return;
        widgetsModel.clear();
        loaderRoot.changed();
    }

    function opBringToFront(id) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1 || idx >= widgetsModel.count - 1) return;
        // move() preserves row identity, so the Widget (PanelWindow) of that
        // row is NOT destroyed and recreated like a remove()+append() would.
        // Stacking note: the Instantiator materializes delegates in model row
        // order, and the compositor layers the resulting surfaces in that
        // (re)map order — i.e. model order defines the visual stacking of the
        // widgets. move() reorders the model cheaply; existing mapped
        // surfaces are not re-raised above already-mapped siblings (that is
        // a wl_surface property), which is fine for the redactor use case.
        widgetsModel.move(idx, widgetsModel.count - 1, 1);
        loaderRoot.changed();
    }

    function opSetVariant(id, variant) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        let item = widgetsModel.get(idx);
        let reg = loaderRoot.registryOf();
        let type = item.wType || "time";
        let t = reg.types[type];
        if (t && t.variants && !t.variants[variant]) return;
        if (!t && !variant) variant = reg.defaultVariant(type);
        widgetsModel.setProperty(idx, "wVariant", variant);
        loaderRoot.changed();
    }

    function opSetGeometry(id, x, y, w, h) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        let item = widgetsModel.get(idx);
        let reg = loaderRoot.registryOf();
        let def = reg.defaultSize(item.wType || "time");
        let g = loaderRoot.sanitizeGeometry(x, y, w, h, def.w, def.h);
        widgetsModel.setProperty(idx, "wX", g.x);
        widgetsModel.setProperty(idx, "wY", g.y);
        widgetsModel.setProperty(idx, "wWidth", g.w);
        widgetsModel.setProperty(idx, "wHeight", g.h);
        loaderRoot.changed();
    }

    function opSetOpacity(id, opacity) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        let o = parseFloat(opacity);
        // Clamp into [0,1]; NaN falls back to fully opaque.
        if (isNaN(o)) o = 1.0;
        widgetsModel.setProperty(idx, "wOpacity", Math.max(0.0, Math.min(1.0, o)));
        loaderRoot.changed();
    }

    function opSetRotation(id, rotation) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        let r = parseFloat(rotation);
        if (isNaN(r)) r = 0;
        widgetsModel.setProperty(idx, "wRotation", r);
        loaderRoot.changed();
    }

    function opSetImagePath(id, imagePath) {
        let idx = loaderRoot.findIndex(id);
        if (idx === -1) return;
        widgetsModel.setProperty(idx, "wImagePath", imagePath || "");
        loaderRoot.changed();
    }

    // Hide the real windows while the redactor for this screen is open.
    function opSetRedactMode(on) {
        loaderRoot.isRedacting = on;
        if (!on) {
            loaderRoot.saveNow(); // flush any pending debounced change
        }
    }

    // --- initial load -------------------------------------------------------------
    Process {
        id: loadProcess
        command: ["bash", "-c", "cat '" + loaderRoot.stateFile + "' 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let trimmed = this.text ? this.text.trim() : "";
                let data = [];
                let corrupt = false;
                if (trimmed !== "") {
                    try {
                        let parsed = JSON.parse(trimmed);
                        if (Array.isArray(parsed)) {
                            data = parsed;
                        } else {
                            corrupt = true; // valid JSON but not a layout list
                        }
                    } catch (e) {
                        corrupt = true;
                    }
                }
                if (corrupt) {
                    // Unreadable layout file: move it aside (bash mv, atomic)
                    // so the corruption is preserved for inspection but stops
                    // shadowing future saves, then continue with an empty
                    // layout. The next user edit re-creates layout.json.
                    let bak = loaderRoot.stateFile + ".bak";
                    Quickshell.execDetached(["bash", "-c", "if [ -f '" + loaderRoot.stateFile + "' ]; then mv -f '" + loaderRoot.stateFile + "' '" + bak + "'; fi"]);
                }
                // Keep the raw persisted layout as the geometry source of
                // truth. The model is built from it with display-only clamps;
                // this path never writes to disk.
                loaderRoot.persistedLayout = data;
                loaderRoot.layoutPending = true;
                loaderRoot.layoutPendingSince = Date.now();
                loaderRoot.tryApplyLayout();
                if (loaderRoot.layoutPending) pendingTimer.start();
            }
        }
    }

    // --- window instantiation ------------------------------------------------------
    Instantiator {
        id: widgetInstantiator
        model: widgetsModel
        delegate: Widget {
            screen: loaderRoot.screen
            registry: loaderRoot.registryOf()
            visible: !loaderRoot.isRedacting
            wId: model.wId
            wType: model.wType
            wVariant: model.wVariant
            wX: model.wX
            wY: model.wY
            wWidth: model.wWidth
            wHeight: model.wHeight
            wOpacity: model.wOpacity
            wRotation: model.wRotation
            wImagePath: model.wImagePath
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", loaderRoot.stateDir]);
        loaderRoot.refreshRedactorInfo();
        WidgetSync.registerLoader(loaderRoot);
        loadProcess.running = true;
    }

    Component.onDestruction: {
        WidgetSync.unregisterLoader(loaderRoot);
    }
}
