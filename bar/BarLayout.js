.pragma library

// ============================================================================
// BarLayout — generic, position-agnostic bar engine.
//
// The bar is now a "bar": a set of ZONES laid out along the bar's main axis
// (start → center → end). Zones are pure data — adding / renaming / removing /
// re-aligning a zone is a JSON edit, never a code change. Each zone carries
// its own visual options (unify, border) so new zones get full styling for
// free.
//
//   bar: {
//     position: "top" | "bottom" | "left" | "right",
//     palette:  "x",
//     thickness: 48,          // height (top/bottom) or width (left/right)
//     edgeGap: 8,             // distance from the screen edge
//     roundness: 1.0,
//     pillBg: true,
//     pillSolid: false,
//     barBg: false,
//     barOpacity: 0.85,
//     dragModules: true,
//     borderWidth: 0, borderColor: "surface1",
//     stylePreset: "modular", // "modular" | "solid" | "fill" — see STYLE_PRESETS
//     zones: [
//       { id, align: "start"|"center"|"end",
//         unify: false, borderWidth: 0, borderColor: "surface1",
//         modules: [ { id, enabled }, ... ] }
//     ]
//   }
//
// Legacy "topbar" settings (the old {left, center, right} model) are migrated
// automatically on first load.
//
// Style presets (Phase D3) are one-click shortcuts over the pill/bar flags:
// `stylePreset` is INFORMATIVE + a shortcut, never destructive — it only
// records which preset was applied last and never overrides manual tweaks
// (applyStylePreset() is the only function that rewrites the flag keys, and it
// touches exactly the keys its preset declares).
// ============================================================================

// --- module catalog (keep in sync with the modules under topbar/modules/) -----
var MODULES = [
    { id: "help",       label: "Help",        icon: "󰅖", component: "modules/HelpModule.qml" },
    { id: "search",     label: "Search",      icon: "󰍉", component: "modules/SearchModule.qml" },
    { id: "settings",   label: "Settings",    icon: "",  component: "modules/SettingsModule.qml" },
    { id: "update",     label: "Updates",     icon: "󰚰", component: "modules/UpdateModule.qml" },
    { id: "time",       label: "Clock",       icon: "󰅐", component: "modules/TimeModule.qml" },
    { id: "date",       label: "Date",        icon: "󰃭", component: "modules/DateModule.qml" },
    { id: "media",      label: "Media",       icon: "󰎈", component: "modules/MediaModule.qml" },
    { id: "workspaces", label: "Workspaces",  icon: "󰽿", component: "modules/WorkspacesModule.qml" },
    { id: "tray",       label: "System tray", icon: "󱊖", component: "modules/TrayModule.qml" },
    { id: "keyboard",   label: "Keyboard",    icon: "󰌌", component: "modules/KeyboardModule.qml" },
    { id: "wifi",       label: "Network",     icon: "󰤨", component: "modules/WifiModule.qml" },
    { id: "bluetooth",  label: "Bluetooth",   icon: "󰂯", component: "modules/BluetoothModule.qml" },
    { id: "sysmon",     label: "Resources",   icon: "󰍛", component: "modules/SysmonModule.qml" },
    { id: "volume",     label: "Volume",      icon: "󰕾", component: "modules/VolumeModule.qml" },
    { id: "battery",    label: "Battery",     icon: "󰁹", component: "modules/BatteryModule.qml" },
    { id: "recording",  label: "Recording",   icon: "",  component: "modules/RecordingModule.qml" },
    { id: "weather",    label: "Weather",     icon: "󰖐", component: "modules/WeatherModule.qml" },
    { id: "focus",      label: "Focus",       icon: "󰋼", component: "modules/FocusModule.qml" }
];

// Module groups used by normalizeBar()/defaultBar() when (re-)adding missing
// modules. NEW_ALWAYS_DISABLED ids were introduced after the zone era: they are
// re-added to existing bars in a disabled state so upgrades never change a
// user's bar layout without their say-so (they enable them in the Bar Editor).
var LEGACY_START_IDS = ["help", "search", "settings", "update", "time", "date", "media"];
var LEGACY_CENTER_IDS = ["workspaces"];
var LEGACY_END_IDS = ["tray", "keyboard", "wifi", "bluetooth", "sysmon", "volume", "battery", "recording"];
var NEW_ALWAYS_DISABLED = ["weather", "focus"];

var POSITIONS = ["top", "bottom", "left", "right"];
var ALIGNS = ["start", "center", "end"];

// --- style presets (Phase D3: one-click bar looks) -----------------------------
// Only the keys a preset declares are applied by applyStylePreset(), so a
// preset never clobbers unrelated manual tweaks:
//   modular: floating islands, no bar strip   -> pills on the raw desktop
//   solid:   continuous bar strip, pills keep their own fill (islands float
//            INSIDE the strip; accent islands stay colored pills)
//   fill:    like solid but edge-to-edge (edgeGap 0, strip touches the edge).
//            The user can re-raise "Edge margin" afterwards; stylePreset is
//            then just an informational label (see header comment).
var STYLE_PRESETS = {
    "modular": { pillBg: true, pillSolid: false, barBg: false },
    "solid": { barBg: true, pillBg: true },
    "fill": { barBg: true, pillBg: true, edgeGap: 0 }
};
var STYLE_PRESET_KEYS = ["modular", "solid", "fill"];

// Arrays that cross the QML <-> JS boundary through `property var` can arrive
// as QVariantList, which breaks `Array.isArray`. Length-based checks are safe.
function isList(x) {
    return x !== null && x !== undefined && typeof x.length === "number";
}

function getModule(id) {
    for (let i = 0; i < MODULES.length; i++) {
        if (MODULES[i].id === id) return MODULES[i];
    }
    return null;
}

function cloneModules(list) {
    let out = [];
    if (!isList(list)) return out;
    for (let i = 0; i < list.length; i++) {
        let e = list[i];
        if (typeof e === "string") {
            out.push({ id: e, enabled: true });
            continue;
        }
        if (!e || !e.id) continue;
        out.push({ id: e.id, enabled: e.enabled !== false });
    }
    return out;
}

// --- island fill API ---------------------------------------------------------
// Per-island and per-block fill control (personalization API). Values are
// canonical strings:
//   "default" -> inherit (zone value, then the bar-wide pill settings)
//   "on"      -> force the pill fill (ignores unified/barBg/pillBg defaults)
//   "off"     -> force a transparent island
// Booleans are accepted for convenience (true -> "on", false -> "off").
function normalizeFillMode(v) {
    if (v === true || v === "on" || v === "filled") return "on";
    if (v === false || v === "off" || v === "none") return "off";
    return "default";
}

// Set the fill for a whole block (zone); islands without their own value
// inherit it.
function setZoneFill(bar, zoneId, mode) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    out.zones[zi].fill = normalizeFillMode(mode);
    return out;
}

// Clock format for the zones engine (Qt.formatDateTime pattern). The classic
// engine keeps its own classicbar.timeFormat.
function setTimeFormat(bar, fmt) {
    let out = cloneBar(bar);
    out.timeFormat = (typeof fmt === "string" && fmt.trim() !== "") ? fmt.trim() : "HH:mm:ss";
    return out;
}

// Date format for the zones engine (Qt.formatDateTime pattern).
function setDateFormat(bar, fmt) {
    let out = cloneBar(bar);
    out.dateFormat = (typeof fmt === "string" && fmt.trim() !== "") ? fmt.trim() : "dddd, MMMM dd";
    return out;
}

// --- module personalization API ----------------------------------------------
// Per-module customization, keyed by module id. User values live in the bar
// config under "modules"; every field is optional:
//   "icon":   glyph override for components that call mod.glyph(...)
//   "color":  content color (a colors.* role name or a #hex string)
//   "fill":   per-island fill ("default" | "on" | "off")
//   "accent": accent role override (turns the island into an accent island)
// The bar-wide "iconColor" sets the default content color for every module.
// Islands that ship with a background by default (palette role fill); the user
// can still force "None" per module.
var DEFAULT_FILLED_MODULES = ["battery", "settings", "search", "time", "help"];

// Accent islands by default: their pill is filled with the palette role, so
// they recolor with the palette (like wifi/bluetooth). Overridable per module.
var DEFAULT_MODULE_ACCENTS = {
    "settings": "mauve",
    "search":   "sapphire",
    "time":     "teal",
    "battery":  "green",
    "help":     "peach"
};

function defaultModuleConfig(id) {
    return {
        icon: "", color: "",
        accent: DEFAULT_MODULE_ACCENTS[id] !== undefined ? DEFAULT_MODULE_ACCENTS[id] : "",
        fill: (DEFAULT_FILLED_MODULES.indexOf(id) !== -1) ? "on" : "default",
        size: 0,          // font px override (0 = module default)
        effect: "",       // per-module view effect ("typewriter" for the clock)
        cursor: true      // blinking cursor for the typewriter effect
    };
}

function normalizeModuleConfig(v, id) {
    let out = defaultModuleConfig(id);
    if (!v || typeof v !== "object") return out;
    if (typeof v.icon === "string") out.icon = v.icon;
    if (typeof v.color === "string") out.color = v.color;
    if (v.fill !== undefined) {
        // An explicit "default" returns to the module's built-in default
        // (filled for DEFAULT_FILLED_MODULES, bar-wide behavior otherwise).
        let mode = normalizeFillMode(v.fill);
        out.fill = (mode === "default") ? out.fill : mode;
    }
    if (typeof v.accent === "string") out.accent = v.accent;  // "" clears the default accent
    if (typeof v.size === "number" && v.size >= 0) out.size = Math.round(v.size);
    if (typeof v.effect === "string") out.effect = v.effect;
    if (v.cursor !== undefined) out.cursor = v.cursor === true;
    return out;
}

// Effective per-module config (defaults + user values).
function moduleConfig(bar, id) {
    if (!bar || !bar.modules || typeof bar.modules !== "object") return defaultModuleConfig(id);
    return normalizeModuleConfig(bar.modules[id], id);
}

function setModuleValue(bar, id, key, value) {
    let out = cloneBar(bar);
    if (!out.modules || typeof out.modules !== "object") out.modules = {};
    let cfg = normalizeModuleConfig(out.modules[id], id);
    cfg[key] = (key === "fill") ? normalizeFillMode(value) : value;
    out.modules[id] = cfg;
    return out;
}
function setModuleIcon(bar, id, glyph)  { return setModuleValue(bar, id, "icon", glyph); }
function setModuleColor(bar, id, color) { return setModuleValue(bar, id, "color", color); }
function setModuleFill(bar, id, mode)   { return setModuleValue(bar, id, "fill", mode); }
function setModuleAccent(bar, id, role) { return setModuleValue(bar, id, "accent", role); }
function setGlobalIconColor(bar, color) { let out = cloneBar(bar); out.iconColor = color; return out; }
function setModuleSize(bar, id, px)   { return setModuleValue(bar, id, "size", px); }
function setModuleEffect(bar, id, v) { return setModuleValue(bar, id, "effect", v); }
function setModuleCursor(bar, id, v) { return setModuleValue(bar, id, "cursor", v); }

// --- defaults -------------------------------------------------------------------
function defaultZone(id, align, modules) {
    return {
        id: id,
        align: align,
        unify: false,
        // Optional container behind the whole zone ("" = off). A color-role
        // name (surface0, mauve, ...); islands keep their own pills on top,
        // so this reads as "capsule inside a capsule". zoneBgSolid makes the
        // container opaque (translucent by default).
        zoneBg: "",
        zoneBgSolid: false,
        borderWidth: 0,
        borderColor: "surface1",
        modules: cloneModules(modules || [])
    };
}

function defaultBar() {
    let zones = [];
    for (let i = 0; i < ALIGNS.length; i++) {
        let align = ALIGNS[i];
        let mods = [];
        for (let m = 0; m < MODULES.length; m++) {
            let id = MODULES[m].id;
            // Legacy distribution: workspaces center, the rest split by
            // catalog order into start/end (weather/focus are appended below,
            // disabled, so fresh installs start exactly like current ones).
            if (align === "center" && LEGACY_CENTER_IDS.indexOf(id) !== -1) mods.push(id);
            else if (align === "start" && LEGACY_START_IDS.indexOf(id) !== -1) mods.push(id);
            else if (align === "end" && LEGACY_END_IDS.indexOf(id) !== -1) mods.push(id);
        }
        zones.push(defaultZone(align, align, mods));
    }
    // New islands ship disabled by default (opt-in in the Bar Editor).
    for (let z = 0; z < zones.length; z++) {
        if (zones[z].align !== "end") continue;
        for (let n = 0; n < NEW_ALWAYS_DISABLED.length; n++) {
            zones[z].modules.push({ id: NEW_ALWAYS_DISABLED[n], enabled: false });
        }
        break;
    }
    return {
        position: "top",
        palette: "x",
        thickness: 48,
        edgeGap: 8,
        roundness: 1.0,
        pillBg: true,
        pillSolid: false,
        barBg: false,
        stylePreset: "modular",
        barOpacity: 0.85,
        dragModules: true,
        borderWidth: 0,
        borderColor: "surface1",
        borderFollowPalette: true,
        borderActive: "",
        borderInactive: "",
        font: "Hack Nerd Font",
        timeFormat: "HH:mm:ss",
        dateFormat: "dddd, MMMM dd",
        modules: {},
        // How EMPTY workspaces render in the Workspaces module:
        // "number" (default), "dot", "letter" or "custom" (the character set in
        // workspacesMarkerText, e.g. a Japanese glyph). Occupied workspaces
        // always show app icons (see WorkspacesModule.qml).
        workspacesMarker: "number",
        workspacesMarkerText: "", // single custom character for marker "custom"
        zones: zones
    };
}

// --- normalization ---------------------------------------------------------------
// Turns whatever sits under settings.json's "bar" key into a safe, complete
// config. Unknown zone/module ids are dropped; missing zones/modules are re-added
// from the catalog so nothing silently disappears.
function normalizeBar(raw) {
    let def = defaultBar();
    if (!raw || typeof raw !== "object") return def;

    let out = {
        position: POSITIONS.indexOf(raw.position) !== -1 ? raw.position : def.position,
        palette: (raw.palette && String(raw.palette).trim() !== "") ? String(raw.palette).toLowerCase() : def.palette,
        thickness: (typeof raw.thickness === "number" && raw.thickness >= 24) ? raw.thickness : def.thickness,
        edgeGap: (typeof raw.edgeGap === "number" && raw.edgeGap >= 0) ? raw.edgeGap : def.edgeGap,
        roundness: (typeof raw.roundness === "number") ? Math.max(0, Math.min(1, raw.roundness)) : def.roundness,
        pillBg: raw.pillBg !== undefined ? (raw.pillBg === true) : def.pillBg,
        pillSolid: raw.pillSolid !== undefined ? (raw.pillSolid === true) : def.pillSolid,
        barBg: raw.barBg !== undefined ? (raw.barBg === true) : def.barBg,
        // stylePreset is a label for the one-click presets + an apply shortcut:
        // it is NEVER used to infer or override pillBg/barBg/... — old configs
        // without the key (even ones that happen to match a preset combo) keep
        // their real values and simply read "modular".
        stylePreset: (typeof raw.stylePreset === "string" && STYLE_PRESETS.hasOwnProperty(raw.stylePreset)) ? raw.stylePreset : def.stylePreset,
        barOpacity: (typeof raw.barOpacity === "number") ? Math.max(0.2, Math.min(1.0, raw.barOpacity)) : def.barOpacity,
        dragModules: raw.dragModules !== undefined ? (raw.dragModules === true) : def.dragModules,
        borderWidth: (typeof raw.borderWidth === "number") ? raw.borderWidth : def.borderWidth,
        borderColor: (typeof raw.borderColor === "string" && raw.borderColor !== "") ? raw.borderColor : def.borderColor,
        borderFollowPalette: raw.borderFollowPalette !== undefined ? (raw.borderFollowPalette === true) : def.borderFollowPalette,
        workspacesMarker: ["number", "dot", "letter", "custom"].indexOf(raw.workspacesMarker) !== -1 ? raw.workspacesMarker : def.workspacesMarker,
        workspacesMarkerText: (typeof raw.workspacesMarkerText === "string") ? raw.workspacesMarkerText.slice(0, 4) : def.workspacesMarkerText,
        borderActive: (typeof raw.borderActive === "string") ? raw.borderActive : def.borderActive,
        borderInactive: (typeof raw.borderInactive === "string") ? raw.borderInactive : def.borderInactive,
        font: (typeof raw.font === "string" && raw.font.trim() !== "") ? raw.font : def.font,
        timeFormat: (typeof raw.timeFormat === "string" && raw.timeFormat.trim() !== "") ? raw.timeFormat : def.timeFormat,
        dateFormat: (typeof raw.dateFormat === "string" && raw.dateFormat.trim() !== "") ? raw.dateFormat : def.dateFormat,
        // Per-module personalization map (see moduleConfig): kept verbatim;
        // entries are normalized on read.
        modules: (raw.modules && typeof raw.modules === "object" && !Array.isArray(raw.modules)) ? raw.modules : def.modules,
        zones: []
    };

    let seen = {};
    let list = isList(raw.zones) ? raw.zones : [];
    for (let i = 0; i < list.length; i++) {
        let z = list[i];
        if (!z || typeof z !== "object" || !z.id || seen[z.id]) continue;
        seen[z.id] = true;
        out.zones.push(defaultZone(
            z.id,
            ALIGNS.indexOf(z.align) !== -1 ? z.align : (z.align || "start"),
            z.modules
        ));
        let zi = out.zones.length - 1;
        out.zones[zi].unify = z.unify === true;
        out.zones[zi].zoneBg = (typeof z.zoneBg === "string") ? z.zoneBg : "";
        out.zones[zi].zoneBgSolid = z.zoneBgSolid === true;
        out.zones[zi].borderWidth = (typeof z.borderWidth === "number") ? z.borderWidth : out.borderWidth;
        out.zones[zi].borderColor = (typeof z.borderColor === "string" && z.borderColor !== "") ? z.borderColor : out.borderColor;
        // drop unknown / duplicate module ids
        let clean = [];
        let mseen = {};
        for (let m = 0; m < out.zones[zi].modules.length; m++) {
            let mid = out.zones[zi].modules[m].id;
            if (!getModule(mid) || mseen[mid]) continue;
            mseen[mid] = true;
            clean.push(out.zones[zi].modules[m]);
        }
        out.zones[zi].modules = clean;
    }

    // Re-add any catalog module missing from the config so it never silently
    // vanishes from the user's bar after an update. Legacy ids come back
    // enabled (as before); NEW_ALWAYS_DISABLED ids come back disabled so an
    // update never surprises the user with new islands.
    let allSeen = {};
    for (let z = 0; z < out.zones.length; z++) {
        for (let m = 0; m < out.zones[z].modules.length; m++) allSeen[out.zones[z].modules[m].id] = true;
    }
    let missingByAlign = { "start": [], "center": [], "end": [] };
    for (let m = 0; m < MODULES.length; m++) {
        if (allSeen[MODULES[m].id]) continue;
        let id = MODULES[m].id;
        // Entries are objects so the enabled flag survives whichever branch
        // (new zone or existing zone) finally places them.
        let entry = { id: id, enabled: NEW_ALWAYS_DISABLED.indexOf(id) === -1 };
        if (id === "workspaces") missingByAlign["center"].push(entry);
        else if (LEGACY_START_IDS.indexOf(id) !== -1) missingByAlign["start"].push(entry);
        else missingByAlign["end"].push(entry);
    }
    for (let align in missingByAlign) {
        if (missingByAlign[align].length === 0) continue;
        let target = null;
        for (let z = 0; z < out.zones.length; z++) {
            if (out.zones[z].align === align) { target = z; break; }
        }
        if (target === null) {
            out.zones.push(defaultZone(align, align, missingByAlign[align]));
        } else {
            for (let m = 0; m < missingByAlign[align].length; m++) {
                out.zones[target].modules.push(missingByAlign[align][m]);
            }
        }
    }

    return out;
}

// --- legacy migration --------------------------------------------------------------
// Old settings.json "topbar" = { left, center, right } + topbarBorder*/Unify*/Roundness.
function migrateFromTopbar(raw) {
    if (!raw || typeof raw.topbar !== "object") return null;

    let t = raw.topbar;
    let zoneOrder = ["left", "center", "right"];
    let alignOf = { "left": "start", "center": "center", "right": "end" };
    let zones = [];
    for (let i = 0; i < zoneOrder.length; i++) {
        let key = zoneOrder[i];
        let entries = isList(t[key]) ? t[key] : [];
        let mods = [];
        for (let m = 0; m < entries.length; m++) {
            let e = entries[m];
            let id = (typeof e === "string") ? e : (e ? e.id : "");
            if (id && getModule(id)) mods.push({ id: id, enabled: e && e.enabled !== false });
        }
        let cap = key.charAt(0).toUpperCase() + key.slice(1);
        zones.push(defaultZone(key, alignOf[key] || "start", mods));
        let zi = zones.length - 1;
        zones[zi].unify = raw["topbarUnify" + cap] === true;
        zones[zi].borderWidth = (typeof raw["topbarBorderWidth" + cap] === "number") ? raw["topbarBorderWidth" + cap] : 0;
        zones[zi].borderColor = (typeof raw["topbarBorderColor" + cap] === "string") ? raw["topbarBorderColor" + cap] : "surface1";
    }

    return {
        position: "top",
        palette: "x",
        thickness: 48,
        edgeGap: 8,
        roundness: (typeof raw.topbarRoundness === "number") ? raw.topbarRoundness : 1.0,
        pillBg: raw.topbarPillBg !== undefined ? raw.topbarPillBg === true : true,
        pillSolid: raw.topbarPillSolid !== undefined ? raw.topbarPillSolid === true : false,
        borderWidth: (typeof raw.topbarBorderWidth === "number") ? raw.topbarBorderWidth : 0,
        borderColor: (typeof raw.topbarBorderColor === "string") ? raw.topbarBorderColor : "surface1",
        zones: zones
    };
}

// Main entry: raw = parsed settings.json. Returns a complete bar config.
function getBar(raw) {
    if (raw && typeof raw.bar === "object" && raw.bar !== null) return normalizeBar(raw.bar);
    let migrated = migrateFromTopbar(raw);
    return migrated ? normalizeBar(migrated) : defaultBar();
}

// --- zone helpers ------------------------------------------------------------------
function zoneIndex(bar, zoneId) {
    if (!bar || !isList(bar.zones)) return -1;
    for (let i = 0; i < bar.zones.length; i++) {
        if (bar.zones[i] && bar.zones[i].id === zoneId) return i;
    }
    return -1;
}

function zoneModel(zone) {
    let out = [];
    if (!zone || !isList(zone.modules)) return out;
    for (let i = 0; i < zone.modules.length; i++) {
        if (zone.modules[i] && zone.modules[i].enabled) out.push(zone.modules[i].id);
    }
    return out;
}

function isEnabled(bar, id) {
    if (!bar || !isList(bar.zones)) return false;
    for (let z = 0; z < bar.zones.length; z++) {
        let zone = bar.zones[z];
        if (!zone || !isList(zone.modules)) continue;
        for (let m = 0; m < zone.modules.length; m++) {
            if (zone.modules[m] && zone.modules[m].id === id) return zone.modules[m].enabled === true;
        }
    }
    return false;
}

// Pure helpers — always return a new object, never mutate the input.
function cloneBar(bar) {
    let out = JSON.parse(JSON.stringify(bar));
    return out;
}

function setEnabled(bar, id, value) {
    let out = cloneBar(bar);
    for (let z = 0; z < out.zones.length; z++) {
        for (let m = 0; m < out.zones[z].modules.length; m++) {
            if (out.zones[z].modules[m].id === id) out.zones[z].modules[m].enabled = value === true;
        }
    }
    return out;
}

function toggleEnabled(bar, id) {
    return setEnabled(bar, id, !isEnabled(bar, id));
}

// Move a module by delta slots inside its zone; at a zone edge hop into the
// neighbouring zone (ordered by alignment order start → center → end).
function moduleMove(bar, id, delta) {
    let out = cloneBar(bar);
    let zi = -1, idx = -1;
    for (let z = 0; z < out.zones.length && zi === -1; z++) {
        for (let m = 0; m < out.zones[z].modules.length; m++) {
            if (out.zones[z].modules[m].id === id) { zi = z; idx = m; break; }
        }
    }
    if (zi === -1) return out;

    let mods = out.zones[zi].modules;
    let next = idx + delta;
    if (next >= 0 && next < mods.length) {
        let tmp = mods[idx];
        mods[idx] = mods[next];
        mods[next] = tmp;
        return out;
    }

    // hop to the neighbouring zone
    let ordered = [];
    for (let z = 0; z < out.zones.length; z++) ordered.push(z);
    ordered.sort((a, b) => ALIGNS.indexOf(out.zones[a].align) - ALIGNS.indexOf(out.zones[b].align));
    let ziOrder = ordered.indexOf(zi);
    let tzOrder = ziOrder + delta;
    if (tzOrder < 0 || tzOrder >= ordered.length) return out;
    let tz = ordered[tzOrder];
    let entry = mods.splice(idx, 1)[0];
    if (delta > 0) out.zones[tz].modules.unshift(entry);
    else out.zones[tz].modules.push(entry);
    return out;
}

// --- drag & drop helpers (live island reordering, Phase D2) --------------------
// Number of ENABLED modules in a zone.
function enabledCount(zone) {
    if (!zone || !isList(zone.modules)) return 0;
    let n = 0;
    for (let i = 0; i < zone.modules.length; i++) {
        if (zone.modules[i] && zone.modules[i].enabled) n++;
    }
    return n;
}

// Index of `id` among the ENABLED modules of a zone (-1 when disabled/missing).
function enabledIndexOf(zone, id) {
    if (!zone || !isList(zone.modules)) return -1;
    let n = 0;
    for (let i = 0; i < zone.modules.length; i++) {
        let m = zone.modules[i];
        if (!m || !m.enabled) continue;
        if (m.id === id) return n;
        n++;
    }
    return -1;
}

// Move module `id` into `targetZoneId` at `insertIndex`. The index is expressed
// over the target zone's ENABLED modules, IGNORING the dragged module itself
// (as if it had already left), and is clamped to [0, enabledCount]. The module
// keeps its `enabled` state. Returns a new bar; never mutates the input.
function moduleMoveTo(bar, id, targetZoneId, insertIndex) {
    if (!bar || !isList(bar.zones)) return bar;
    let out = cloneBar(bar);
    let srcZone = -1, srcIdx = -1;
    for (let z = 0; z < out.zones.length && srcZone === -1; z++) {
        let mods = out.zones[z].modules;
        for (let m = 0; m < mods.length; m++) {
            if (mods[m] && mods[m].id === id) { srcZone = z; srcIdx = m; break; }
        }
    }
    if (srcZone === -1) return out;
    let tz = zoneIndex(out, targetZoneId);
    if (tz === -1) return out;

    let entry = out.zones[srcZone].modules.splice(srcIdx, 1)[0];
    if (srcZone === tz) {
        // Removing from the same zone shifted indices: the target index was
        // computed without the dragged module, which is exactly the state we
        // are in now — insert directly.
        let cap = enabledCount(out.zones[tz]);
        let at = Math.max(0, Math.min(cap, isFinite(insertIndex) ? insertIndex : cap));
        let placed = false;
        let seen = 0;
        let mods = out.zones[tz].modules;
        for (let i = 0; i <= mods.length; i++) {
            if (seen === at) { mods.splice(i, 0, entry); placed = true; break; }
            if (i < mods.length && mods[i] && mods[i].enabled) seen++;
        }
        if (!placed) mods.push(entry);
        return out;
    }

    // Different zone: insert among its enabled modules at the requested slot.
    let cap = enabledCount(out.zones[tz]);
    let at = Math.max(0, Math.min(cap, isFinite(insertIndex) ? insertIndex : cap));
    let mods = out.zones[tz].modules;
    let seen = 0;
    let placed = false;
    for (let i = 0; i <= mods.length; i++) {
        if (seen === at) { mods.splice(i, 0, entry); placed = true; break; }
        if (i < mods.length && mods[i] && mods[i].enabled) seen++;
    }
    if (!placed) mods.push(entry);
    return out;
}

// --- style presets & quick layouts (Phase D3, pure) ------------------------------
// Apply a one-click style preset to a copy of `bar`. Only the keys declared by
// the preset are written; stylePreset records the preset for the editor badge.
// Invalid presets leave the bar untouched (still returns a clone: never
// returns the caller's object).
function applyStylePreset(bar, preset) {
    let out = cloneBar(bar);
    if (!STYLE_PRESETS.hasOwnProperty(preset)) return out;
    let p = STYLE_PRESETS[preset];
    for (let key in p) {
        if (p.hasOwnProperty(key)) out[key] = p[key];
    }
    out.stylePreset = preset;
    return out;
}

// Index of the first zone aligned `align` (-1 when none). Pure.
function firstZoneWithAlign(bar, align) {
    if (!bar || !isList(bar.zones)) return -1;
    for (let z = 0; z < bar.zones.length; z++) {
        if (bar.zones[z] && bar.zones[z].align === align) return z;
    }
    return -1;
}

// "Center all": gather every ENABLED module (in catalog order) into the first
// zone aligned `align`, creating that zone when the bar has none. Modules keep
// their enabled state; DISABLED entries are never moved (they stay in their own
// zones) and emptied zones are not removed. The target zone keeps its own
// disabled entries, appended after the enabled cluster so the visible islands
// read in a clean block. Returns a new bar; never mutates the input.
function arrangeAllInZone(bar, align) {
    if (!bar || !isList(bar.zones) || ALIGNS.indexOf(align) === -1) return bar;
    let out = cloneBar(bar);

    // Enabled module ids, ordered by the catalog (not by their current zones).
    let enabledHere = {};
    for (let z = 0; z < out.zones.length; z++) {
        let mods = out.zones[z].modules;
        if (!isList(mods)) continue;
        for (let m = 0; m < mods.length; m++) {
            if (mods[m] && mods[m].enabled) enabledHere[mods[m].id] = true;
        }
    }
    let wanted = [];
    for (let m = 0; m < MODULES.length; m++) {
        if (enabledHere[MODULES[m].id]) wanted.push(MODULES[m].id);
    }
    if (wanted.length === 0) return out;

    // Target zone: reuse the first `align` zone or append a fresh one.
    let zi = firstZoneWithAlign(out, align);
    if (zi === -1) {
        let nid = align;
        let n = 2;
        while (zoneIndex(out, nid) !== -1) nid = align + n++;
        out.zones.push(defaultZone(nid, align, []));
        zi = out.zones.length - 1;
    }

    // Strip every enabled entry from ALL zones (disabled entries stay where
    // they are), then rebuild the target as enabled-block + its own disabled.
    for (let z = 0; z < out.zones.length; z++) {
        let mods = out.zones[z].modules;
        if (!isList(mods)) continue;
        out.zones[z].modules = mods.filter(m => !(m && m.enabled));
    }
    let block = [];
    for (let i = 0; i < wanted.length; i++) block.push({ id: wanted[i], enabled: true });
    out.zones[zi].modules = block.concat(out.zones[zi].modules);
    return out;
}

// --- zone CRUD (used by the settings editor) ---------------------------------------
function addZone(bar, align, afterZoneId) {
    let out = cloneBar(bar);
    let id = "zone" + (Date.now() % 100000);
    let zi = zoneIndex(out, afterZoneId);
    let z = defaultZone(id, ALIGNS.indexOf(align) !== -1 ? align : "start", []);
    if (zi === -1) out.zones.push(z);
    else out.zones.splice(zi + 1, 0, z);
    return out;
}

function removeZone(bar, zoneId) {
    let out = cloneBar(bar);
    if (out.zones.length <= 1) return out; // keep at least one zone
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    // move orphaned modules to the first zone instead of dropping them
    let orphans = out.zones[zi].modules;
    out.zones.splice(zi, 1);
    if (orphans.length > 0 && out.zones.length > 0) {
        out.zones[0].modules = out.zones[0].modules.concat(orphans);
    }
    return out;
}

function renameZone(bar, zoneId, newId) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    let clean = String(newId || "").trim().toLowerCase().replace(/[^a-z0-9_-]/g, "");
    if (clean === "" || zoneIndex(out, clean) !== -1) return out;
    out.zones[zi].id = clean;
    return out;
}

function setZoneAlign(bar, zoneId, align) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1 || ALIGNS.indexOf(align) === -1) return out;
    out.zones[zi].align = align;
    return out;
}

function setZoneUnify(bar, zoneId, value) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    out.zones[zi].unify = value === true;
    return out;
}

// Set (or clear with "") the container background role of a zone. Pure.
function setZoneBg(bar, zoneId, role) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    out.zones[zi].zoneBg = String(role || "");
    return out;
}

// Opaque vs translucent container fill (pure).
function setZoneBgSolid(bar, zoneId, solid) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    out.zones[zi].zoneBgSolid = solid === true;
    return out;
}

function setZoneBorder(bar, zoneId, width, color) {
    let out = cloneBar(bar);
    let zi = zoneIndex(out, zoneId);
    if (zi === -1) return out;
    if (typeof width === "number") out.zones[zi].borderWidth = width;
    if (typeof color === "string" && color !== "") out.zones[zi].borderColor = color;
    return out;
}

// Flat list of every module for the settings editor, tagged with zone info.
function flatten(bar) {
    let out = [];
    if (!bar || !isList(bar.zones)) return out;
    for (let z = 0; z < bar.zones.length; z++) {
        let zone = bar.zones[z];
        if (!zone || !isList(zone.modules)) continue;
        for (let m = 0; m < zone.modules.length; m++) {
            let mod = getModule(zone.modules[m].id);
            if (!mod) continue;
            out.push({
                id: mod.id, label: mod.label, icon: mod.icon,
                zone: zone.id, zoneAlign: zone.align,
                enabled: zone.modules[m].enabled === true,
                isFirst: m === 0, isLast: m === zone.modules.length - 1
            });
        }
    }
    return out;
}

// --- classicbar: classic left/center/right engine (Phase D4-E1a, pure) --------------
// The classic classicantinum-style bar lives under settings.json's top-level
// "classicbar" key; the zone-based "bar" engine above stays untouched. A classicbar
// has three sections (left/center/right) whose lists hold loose module ids and
// arrays ("groups"): a group is ONE visual pill hosting several modules (the
// counterpart of classicantinum's center pill ["timedate", "info", "weather"]).
// Every function here is pure: it returns fresh objects and never mutates its
// inputs.

// Layout tokens. As a LOOSE section entry a token stands for a cluster of
// modules that the renderer expands at draw time ("center" = the classic
// centered time+weather cluster). Tokens are plain data in this file —
// normalizeClassicbar() keeps them as-is and never expands them.
var SERP_TOKEN_IDS = ["center", "centerbox"];

// Module ids a token stands for; a valid catalog module id answers with
// itself (so this doubles as the normalizer's validity lookup) and anything
// unknown answers []. Always returns a fresh array.
function classicTokenModules(id) {
    if (typeof id !== "string") return [];
    if (SERP_TOKEN_IDS.indexOf(id) !== -1) return ["time", "weather"];
    if (getModule(id)) return [id];
    return [];
}

// Fresh, complete default classicbar config. Note the classic shapes: center is
// exactly ONE group of three (the timeless pill), while left/right mix loose
// ids with a single system group on the right.
//
// Visual keys (Phase R1, classicantium BarTab parity):
//   distinctPills  — bool, default false (classicantium Bar.qml:93-96 reads
//                    bar.distinctPills with the same default; only meaningful
//                    for the solid/fill strip — see ClassicBar.qml).
//   thickness      — px (24-120) or null = "inherit the host bar thickness"
//                    (null is the DEFAULT: the classic bar keeps the band size
//                    the user's bar engine has; an explicit number overrides
//                    it). classicantium has no knob (Bar.qml:244 fixes barHeight
//                    at s(40)); the knob exists here because hyprland's bar
//                    thickness is user-tunable and the engines share a window.
//   opacity        — percent 20-100 (default 100, like classicantium BarTab's
//                    bar.opacity default 100, BarTab.qml:33-49). Drives the
//                    strip alpha (opacity/100); upstream range is 1-100 but we
//                    clamp at 20 so the strip never becomes unreadable.
function classicbarDefaults() {
    return {
        position: "top",
        style: "modular",
        widthPercent: 100,
        autohide: false,
        autohideTimeout: 800,
        distinctPills: false,
        roundness: 0.6,          // island/strip/group corner radius knob (0..1)
        timeFormat: "HH:mm:ss",  // clock island format (classic engine)
        thickness: 40,           // classicantium band s(40) parity; null = inherit bar thickness
        opacity: 100,          // opaque strip (classicantium default)
        modules: {
            left: ["help", "search", "settings", "media"],
            center: [["time", "date", "weather"]],
            right: [["keyboard", "wifi", "bluetooth", "volume", "battery"], "tray", "update"]
        }
    };
}

// Sanitize arbitrary data into a complete classicbar config. Every section list
// may hold loose strings (catalog module ids or SERP_TOKEN_IDS tokens) and
// arrays (groups of catalog module ids). Per-section rules:
//   - no module id may appear twice: one claim pass over the EXPANDED ids in
//     list order. A loose id/token that collides with an earlier claim is
//     dropped whole (tokens are opaque data, they cannot be half-kept); a
//     group only loses its colliding members;
//   - a group must keep >= 2 valid members: with exactly 1 it flattens to a
//     loose id, with 0 it disappears. Tokens are only admitted LOOSE — inside
//     a group they are invalid members like any unknown id;
//   - unknown ids are discarded everywhere.
// Always returns a brand-new object with every key; never mutates `raw`.
function normalizeClassicbar(raw) {
    let def = classicbarDefaults();
    if (!raw || typeof raw !== "object") return def;

    function cleanSection(src) {
        let out = [];
        let seen = {};
        for (let i = 0; i < src.length; i++) {
            let entry = src[i];
            if (typeof entry === "string") {
                let expanded = classicTokenModules(entry);
                if (expanded.length === 0) continue; // unknown id -> discard
                let dup = false;
                for (let e = 0; e < expanded.length && !dup; e++) {
                    if (seen[expanded[e]]) dup = true;
                }
                if (dup) continue;
                for (let e = 0; e < expanded.length; e++) seen[expanded[e]] = true;
                out.push(entry); // keep the raw data: tokens stay tokens
            } else if (isList(entry)) {
                let kept = [];
                for (let m = 0; m < entry.length; m++) {
                    let sub = entry[m];
                    if (typeof sub !== "string") continue;
                    if (!getModule(sub)) continue; // tokens/unknown ids not allowed in groups
                    if (seen[sub]) continue; // later claims lose
                    seen[sub] = true;
                    kept.push(sub);
                }
                if (kept.length >= 2) out.push(kept);
                else if (kept.length === 1) out.push(kept[0]); // flatten to a loose id
            }
        }
        return out;
    }

    let out = {
        position: POSITIONS.indexOf(raw.position) !== -1 ? raw.position : def.position,
        style: STYLE_PRESET_KEYS.indexOf(raw.style) !== -1 ? raw.style : def.style,
        widthPercent: (typeof raw.widthPercent === "number" && isFinite(raw.widthPercent))
            ? Math.max(40, Math.min(100, raw.widthPercent)) : def.widthPercent,
        autohide: raw.autohide !== undefined ? (raw.autohide === true) : def.autohide,
        autohideTimeout: (typeof raw.autohideTimeout === "number" && isFinite(raw.autohideTimeout))
            ? Math.max(200, Math.min(5000, raw.autohideTimeout)) : def.autohideTimeout,
        // Phase R1 visual keys (see classicbarDefaults for semantics/citations).
        distinctPills: raw.distinctPills !== undefined ? (raw.distinctPills === true) : def.distinctPills,
        roundness: (typeof raw.roundness === "number" && isFinite(raw.roundness))
            ? Math.max(0, Math.min(1, raw.roundness)) : def.roundness,
        timeFormat: ["HH:mm", "HH:mm:ss", "h:mm a"].indexOf(raw.timeFormat) !== -1 ? raw.timeFormat : def.timeFormat,
        thickness: (raw.thickness === null || raw.thickness === undefined)
            ? (raw.thickness === undefined ? def.thickness : null)
            : (typeof raw.thickness === "number" && isFinite(raw.thickness)
                ? Math.max(24, Math.min(120, raw.thickness)) : def.thickness),
        opacity: (typeof raw.opacity === "number" && isFinite(raw.opacity))
            ? Math.max(20, Math.min(100, Math.round(raw.opacity))) : def.opacity,
        modules: {}
    };
    let srcMods = (raw.modules && typeof raw.modules === "object") ? raw.modules : null;
    let names = classicSectionNames();
    for (let s = 0; s < names.length; s++) {
        let key = names[s];
        let src = (srcMods && isList(srcMods[key])) ? srcMods[key] : [];
        out.modules[key] = cleanSection(src);
    }
    return out;
}

// Main entry: raw = parsed settings.json. Reads the top-level "classicbar" key.
function getClassicbar(raw) {
    if (raw && typeof raw.classicbar === "object" && raw.classicbar !== null) {
        return normalizeClassicbar(raw.classicbar);
    }
    return classicbarDefaults();
}

// Convert a NORMALIZED zone bar (as produced by getBar()/normalizeBar())
// into classicbar modules. Zones are walked in bar.zones order and mapped by
// alignment (start/center/end -> left/center/right); only ENABLED modules are
// collected, in zone order, disabled entries are skipped. A module can only
// appear once overall — the first occurrence wins. Center follows the classic
// model: 3+ modules collapse into ONE group, 1-2 stay loose.
function barToClassicModules(bar) {
    let out = { left: [], center: [], right: [] };
    if (!bar || !isList(bar.zones)) return out;
    let seen = {};
    for (let z = 0; z < bar.zones.length; z++) {
        let zone = bar.zones[z];
        if (!zone || !isList(zone.modules)) continue;
        let target = null;
        if (zone.align === "start") target = out.left;
        else if (zone.align === "center") target = out.center;
        else if (zone.align === "end") target = out.right;
        if (target === null) continue; // unknown align -> no section
        for (let m = 0; m < zone.modules.length; m++) {
            let e = zone.modules[m];
            if (!e || e.enabled !== true) continue;
            if (!getModule(e.id) || seen[e.id]) continue;
            seen[e.id] = true;
            target.push(e.id);
        }
    }
    if (out.center.length >= 3) out.center = [out.center];
    return out;
}

// Visual flag sets per classicbar style. Same vocabulary (and same values) as the
// bar STYLE_PRESETS above — this clones the matching preset so the two can
// never drift apart and callers may mutate the result freely:
//   modular: floating islands on the raw desktop    -> pill background only
//   solid:   continuous bar strip, islands keep their own fill
//   fill:    like solid but edge-to-edge (edgeGap 0)
// Unknown styles yield {} (nothing applies). "fill" also conceptually forces
// widthPercent to 100, but that key is NOT returned — the renderer decides it
// through isFillStyle().
// Visual flags for the SERP bar styles (its own map — deliberately NOT the
// bar STYLE_PRESETS: the classic bar draws flat content on the strip, so
// solid/fill disable the island fill (pillBg:false) to avoid the "double
// fill" look; module state colors survive through the host accentTintMode).
var SERP_STYLE_FLAGS = {
    "modular": { pillBg: true,  pillSolid: false, barBg: false },
    "solid":   { pillBg: false, barBg: true },
    "fill":    { pillBg: false, barBg: true, edgeGap: 0 }
};
function classicStyleFlags(style) {
    let preset = SERP_STYLE_FLAGS.hasOwnProperty(style) ? SERP_STYLE_FLAGS[style] : null;
    let out = {};
    if (!preset) return out;
    for (let key in preset) {
        if (preset.hasOwnProperty(key)) out[key] = preset[key];
    }
    return out;
}

function isFillStyle(style) {
    return style === "fill";
}

// Fixed order of the classic sections (used by the normalizers above).
function classicSectionNames() {
    return ["left", "center", "right"];
}

// --- classicbar editing helpers (Phase D4-E2, pure) ---------------------------------
// Helpers powering the Classic engine UI of the BarEditor (Engine/Position/Style
// & size/Modules/Actions cards). The editor renders each section as a list of
// ITEMS: loose entries (catalog module ids or layout tokens) and arrays
// ("groups": ONE visual pill hosting >= 2 modules). Every index in these
// helpers counts over ITEMS (a group counts as exactly one).
//
// Duplicate policy (documented decision): a module id may never sit twice in
// the SAME section list, so an operation that would place `id` into a list
// which already claims it (as a loose entry, inside a group or through a
// layout token expansion) is a NO-OP and returns the input unchanged. This
// matches what normalizeClassicbar() tolerates (its per-section claim pass) and
// what the editor shows (chips never duplicate inside a card). Different
// sections may hold the same module, but the editor can never CREATE that
// state because every drag detaches the module from its source first.
//
// All functions are pure: they return fresh, normalized objects and never
// mutate their inputs (no-ops return the input object itself, mirroring
// moduleMoveTo()). Layout tokens ("center"/"centerbox") are plain data here,
// exactly as in normalizeClassicbar() — they can only be moved/removed whole.

// Deep copy of a classicbar config (serialize/deserialize, like cloneBar).
function classicClone(cfg) {
    return JSON.parse(JSON.stringify(cfg));
}

// The raw items of one section list as a fresh array (loose strings and group
// arrays, in order). Unknown lists answer []. Pure read for rendering.
function classicSectionItems(cfg, list) {
    if (!cfg || typeof cfg !== "object") return [];
    let mods = (cfg.modules && typeof cfg.modules === "object") ? cfg.modules : null;
    if (!mods || !isList(mods[list])) return [];
    let arr = mods[list];
    let out = [];
    for (let i = 0; i < arr.length; i++) out.push(arr[i]);
    return out;
}

// Fill `claimMap` with the module ids one section entry stands for: a loose
// module id claims itself, a loose token claims the modules it expands to
// (classicTokenModules), a group claims its member ids. Private.
function classicEntryClaims(entry, claimMap) {
    if (typeof entry === "string") {
        let expanded = classicTokenModules(entry);
        for (let i = 0; i < expanded.length; i++) claimMap[expanded[i]] = true;
    } else if (isList(entry)) {
        for (let i = 0; i < entry.length; i++) {
            let sub = entry[i];
            if (typeof sub === "string" && getModule(sub)) claimMap[sub] = true;
        }
    }
}

// Map of every module id claimed by the items of ONE section list. Private.
function classicListClaims(cfg, list) {
    let out = {};
    if (!cfg || typeof cfg !== "object") return out;
    let mods = (cfg.modules && typeof cfg.modules === "object") ? cfg.modules : null;
    if (!mods || !isList(mods[list])) return out;
    let arr = mods[list];
    for (let i = 0; i < arr.length; i++) classicEntryClaims(arr[i], out);
    return out;
}

// Map of every module id claimed across ALL sections. Private.
function classicAllClaims(cfg) {
    let out = {};
    let names = classicSectionNames();
    for (let s = 0; s < names.length; s++) {
        let c = classicListClaims(cfg, names[s]);
        for (let id in c) {
            if (c.hasOwnProperty(id)) out[id] = true;
        }
    }
    return out;
}

// Is `id` present in any section: loose, inside a group, or claimed by a
// layout token (tokens stand for their expanded modules on the bar).
function classicContainsAny(cfg, id) {
    if (typeof id !== "string") return false;
    return classicAllClaims(cfg).hasOwnProperty(id);
}

// Catalog module ids NOT claimed by any section, in catalog order — the
// editor's "Available" pool. Pure read.
function classicAvailableModules(cfg) {
    let claims = classicAllClaims(cfg);
    let out = [];
    for (let m = 0; m < MODULES.length; m++) {
        if (!claims.hasOwnProperty(MODULES[m].id)) out.push(MODULES[m].id);
    }
    return out;
}

// Remove `id` from whichever section holds it (one occurrence): a loose entry
// is removed whole; a group member is removed and the group is rebalanced (2+
// members stay a group, 1 member flattens to a loose id at the group's spot,
// 0 members removes the group). Mutates `cfg`, which must be a clone owned by
// the caller. Returns true when an occurrence was found and removed.
// NOTE: isList() is length-based, so plain strings answer true — every group
// branch must exclude them first (loose ids are handled by the === branch).
function classicDetach(cfg, id) {
    if (typeof id !== "string") return false;
    let names = classicSectionNames();
    for (let s = 0; s < names.length; s++) {
        let list = cfg.modules[names[s]];
        if (!isList(list)) continue;
        for (let i = 0; i < list.length; i++) {
            let entry = list[i];
            if (entry === id) {
                list.splice(i, 1);
                return true;
            }
            if (typeof entry !== "string" && isList(entry)) {
                let mi = entry.indexOf(id);
                if (mi === -1) continue;
                entry.splice(mi, 1);
                if (entry.length >= 2) return true;
                if (entry.length === 1) {
                    list[i] = entry[0];
                    return true;
                }
                list.splice(i, 1);
                return true;
            }
        }
    }
    return false;
}

// Safety pass over every section: groups lose unknown/duplicate members, a
// group left with one member flattens to a loose id, with zero it disappears.
// Pure: works on a deep clone and returns it (the input is never touched).
// The move helpers call it after their own mutation (on their private clone).
// NOTE: isList() is length-based, so loose strings must be skipped explicitly.
function classicRemoveEmptyGroups(cfg) {
    if (!cfg || typeof cfg !== "object") return cfg;
    let out = classicClone(cfg);
    let names = classicSectionNames();
    for (let s = 0; s < names.length; s++) {
        let list = isList(out.modules[names[s]]) ? out.modules[names[s]] : null;
        if (!list) continue;
        for (let i = list.length - 1; i >= 0; i--) {
            let entry = list[i];
            if (typeof entry === "string" || !isList(entry)) continue;
            let kept = [];
            for (let m = 0; m < entry.length; m++) {
                let sub = entry[m];
                if (typeof sub === "string" && getModule(sub) && kept.indexOf(sub) === -1) kept.push(sub);
            }
            if (kept.length >= 2) list[i] = kept;
            else if (kept.length === 1) list[i] = kept[0];
            else list.splice(i, 1);
        }
    }
    return out;
}

// Move module `id` (loose or group member, or a whole layout token) out of
// wherever it sits and insert it into `toList` as a LOOSE entry at
// `insertIndex`. The index counts over the destination's ITEMS AFTER the
// removal (the dragged entry is no longer there) and is clamped.
// `toList === "available"` only removes the module from the bar. Duplicate
// policy: if the destination list still claims `id` after the removal the
// call is a NO-OP (see the block comment above). Returns a fresh config.
function classicMoveTo(cfg, id, toList, insertIndex) {
    if (typeof id !== "string") return cfg;
    if (!getModule(id) && SERP_TOKEN_IDS.indexOf(id) === -1) return cfg; // unknown id
    if (toList !== "available" && classicSectionNames().indexOf(toList) === -1) return cfg;
    let out = classicClone(cfg);
    classicDetach(out, id);
    if (toList === "available") {
        return normalizeClassicbar(classicRemoveEmptyGroups(out));
    }
    // No-op when the destination list already claims the id after the detach
    // (the module may only have come from a different section — a same-list
    // removal freed its own spot).
    if (classicListClaims(out, toList).hasOwnProperty(id)) return cfg;
    let list = out.modules[toList];
    let at = isFinite(insertIndex) ? Math.max(0, Math.min(list.length, insertIndex)) : list.length;
    list.splice(at, 0, id);
    return normalizeClassicbar(classicRemoveEmptyGroups(out));
}

// Move the group ITEM at `itemIndex` of section `fromList` (must be a group)
// to `toList` at `insertIndex` over ITEMS (computed as if the group had
// already left; clamped). `toList === "available"` releases the whole group:
// every member leaves the bar. Duplicate policy: when any member is already
// claimed by the destination (excluding the group's own members when it moves
// within its own section) the call is a NO-OP. Returns a fresh config.
function classicMoveGroupTo(cfg, fromList, itemIndex, toList, insertIndex) {
    let names = classicSectionNames();
    if (names.indexOf(fromList) === -1) return cfg;
    if (toList !== "available" && names.indexOf(toList) === -1) return cfg;
    let out = classicClone(cfg);
    let src = out.modules[fromList];
    if (!isList(src) || !isFinite(itemIndex) || itemIndex < 0 || itemIndex >= src.length) return cfg;
    let group = src[itemIndex];
    if (typeof group === "string" || !isList(group)) return cfg;
    if (toList !== "available") {
        let claims = classicListClaims(out, toList);
        if (fromList === toList) {
            // The group's own members travel along: never a self-conflict.
            for (let m = 0; m < group.length; m++) delete claims[group[m]];
        }
        for (let m = 0; m < group.length; m++) {
            if (claims.hasOwnProperty(group[m])) return cfg;
        }
    }
    src.splice(itemIndex, 1);
    if (toList === "available") return normalizeClassicbar(classicRemoveEmptyGroups(out));
    let list = out.modules[toList];
    let at = isFinite(insertIndex) ? Math.max(0, Math.min(list.length, insertIndex)) : list.length;
    list.splice(at, 0, group);
    return normalizeClassicbar(classicRemoveEmptyGroups(out));
}

// Break the group ITEM at `itemIndex` of section `list` into its loose member
// entries at the same spot (the group's position is preserved). Pure.
function classicUngroup(cfg, list, itemIndex) {
    if (classicSectionNames().indexOf(list) === -1) return cfg;
    let out = classicClone(cfg);
    let arr = out.modules[list];
    if (!isList(arr) || !isFinite(itemIndex) || itemIndex < 0 || itemIndex >= arr.length) return cfg;
    let group = arr[itemIndex];
    if (typeof group === "string" || !isList(group)) return cfg;
    let loose = [];
    for (let i = 0; i < group.length; i++) {
        if (typeof group[i] === "string") loose.push(group[i]);
    }
    arr.splice.apply(arr, [itemIndex, 1].concat(loose));
    return normalizeClassicbar(classicRemoveEmptyGroups(out));
}

// Append module `id` to the group ITEM at `groupIndex` of section `list`,
// detaching it from wherever it sits first (the UI only offers join when the
// target group does not already contain the id — the engine guards too, and
// groups never host layout tokens). Joining keeps the group at 2+ members.
// Duplicate policy applies to the destination list like everywhere else: when
// the list claims `id` after the detach (it sat loose in the SAME section and
// the user dropped it onto a group), the module is still appended — it left
// its loose spot, so no duplicate is created. Pure.
function classicJoinGroup(cfg, id, list, groupIndex) {
    if (typeof id !== "string" || !getModule(id)) return cfg; // only catalog modules join groups
    if (classicSectionNames().indexOf(list) === -1) return cfg;
    let out = classicClone(cfg);
    let arr = out.modules[list];
    if (!isList(arr) || !isFinite(groupIndex) || groupIndex < 0 || groupIndex >= arr.length) return cfg;
    let group = arr[groupIndex];
    if (typeof group === "string" || !isList(group) || group.indexOf(id) !== -1) return cfg;
    // Group array identity survives the detach (even when the detach flattens
    // an earlier group of the same section), so appending always lands inside
    // the intended cluster.
    classicDetach(out, id);
    group.push(id);
    return normalizeClassicbar(classicRemoveEmptyGroups(out));
}
