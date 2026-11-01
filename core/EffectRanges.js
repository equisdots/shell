.pragma library

// ═══════════════════════════════════════════════════════════════════════════
// EffectRanges — single source for the window-effect limits.
//
// Shared by core/HyprEffects.qml and the two effect editors. The limits follow
// Hyprland 0.57, which validates decoration/general options and rejects
// out-of-range values in Lua configs. The kernel script
// (core/scripts/hypr-effects.sh) mirrors the same numbers.
//
// RANGES: numeric keys accepted by the effects kernel.
//   kind  "int" | "float" | "bool"
//   step  UI granularity only (clamp() does not snap; persisted values keep
//         the user's own precision).
// VARIANTS: decoration:blur:variant, ordered exactly like Hyprland's enum.
// ═══════════════════════════════════════════════════════════════════════════

var RANGES = {
    // decoration:active_opacity / inactive_opacity (0..1)
    active_opacity:      { min: 0,    max: 1,   step: 0.05, default: 0.85, kind: "float" },
    inactive_opacity:    { min: 0,    max: 1,   step: 0.05, default: 0.80, kind: "float" },

    // decoration:rounding (0..100 since 0.57)
    rounding:            { min: 0,    max: 100, step: 1,    default: 20,   kind: "int" },

    // decoration:blur:size (0..100) / passes (0..10)
    blur_size:           { min: 0,    max: 100, step: 1,    default: 8,    kind: "int" },
    blur_passes:         { min: 0,    max: 10,  step: 1,    default: 3,    kind: "int" },

    // general:gaps_in / gaps_out (css_gaps; the kernel reads the first side)
    gaps_in:             { min: 0,    max: 100, step: 2,    default: 16,   kind: "int" },
    gaps_out:            { min: 0,    max: 100, step: 2,    default: 25,   kind: "int" },

    // general:border_size (0..20)
    border_size:         { min: 0,    max: 20,  step: 1,    default: 2,    kind: "int" },

    // decoration:shadow:range (0..100) / render_power (1..4)
    shadow_range:        { min: 0,    max: 100, step: 1,    default: 35,   kind: "int" },
    shadow_render_power: { min: 1,    max: 4,   step: 1,    default: 4,    kind: "int" },

    // decoration:shadow:offset (Hyprland accepts any int; keep a sane window)
    shadow_offset_x:     { min: -100, max: 100, step: 1,    default: 0,    kind: "int" },
    shadow_offset_y:     { min: -100, max: 100, step: 1,    default: 10,   kind: "int" },

    // 0.57-only keys. blur_proportional is a bool stored as 0/1 in JSON.
    blur_proportional:   { min: 0,    max: 1,   step: 1,    default: 0,    kind: "bool" },
    wobble_enabled:      { min: 0,    max: 1,   step: 1,    default: 0,    kind: "bool" },
    wobble_intensity:    { min: 0,    max: 2,   step: 0.05, default: 0.2,  kind: "float" }
};

// Ordered like Hyprland's decoration:blur:variant enum (0..10). `cost` is a
// short UI hint; animated variants re-run their shader every frame.
var VARIANTS = [
    { index: 0,  name: "kawase",       cost: "low",    animated: false, hint: "Default, cheapest" },
    { index: 1,  name: "frost",        cost: "low",    animated: false, hint: "Static, low cost" },
    { index: 2,  name: "ripple",       cost: "high",   animated: true,  hint: "Animated, high cost" },
    { index: 3,  name: "drops",        cost: "medium", animated: true,  hint: "Animated, medium cost" },
    { index: 4,  name: "water",        cost: "high",   animated: true,  hint: "Animated, high cost" },
    { index: 5,  name: "fluid_jar",    cost: "high",   animated: true,  hint: "Animated, high cost" },
    { index: 6,  name: "prism",        cost: "medium", animated: false, hint: "Static, medium cost" },
    { index: 7,  name: "heat_shimmer", cost: "high",   animated: true,  hint: "Animated, high cost" },
    { index: 8,  name: "acrylic",      cost: "medium", animated: false, hint: "Glass, medium cost" },
    { index: 9,  name: "aurora",       cost: "high",   animated: true,  hint: "Animated, high cost" },
    { index: 10, name: "haze",         cost: "high",   animated: true,  hint: "Animated, high cost" }
];

// Canonical list of names, in enum order (for cycle controls).
function variantNames() {
    var out = [];
    for (var i = 0; i < VARIANTS.length; i++) out.push(VARIANTS[i].name);
    return out;
}

// Accepts a name, a numeric index, or an unknown value; unknown -> kawase (0).
function variantIndex(name) {
    if (typeof name === "number" && isFinite(name))
        return Math.max(0, Math.min(VARIANTS.length - 1, Math.round(name)));
    var key = String(name === undefined || name === null ? "" : name)
        .trim().toLowerCase().replace(/-/g, "_");
    // Numeric strings are accepted too (hyprctl may report the enum index).
    if (/^[0-9]+$/.test(key))
        return Math.max(0, Math.min(VARIANTS.length - 1, parseInt(key, 10)));
    for (var i = 0; i < VARIANTS.length; i++)
        if (VARIANTS[i].name === key) return i;
    return 0;
}

function variantName(index) {
    return VARIANTS[variantIndex(index)].name;
}

// Full record for the UI (cost/animated/hint).
function variantInfo(name) {
    return VARIANTS[variantIndex(name)];
}

function variantHint(name) {
    return variantInfo(name).hint;
}

function variantCost(name) {
    return variantInfo(name).cost;
}

// Clamp a value to its Hyprland range. Strings are canonicalized for
// blur_variant; booleans are normalised to 0/1; unknown keys pass through.
function clamp(key, value) {
    if (key === "blur_variant")
        return variantName(variantIndex(value));

    var range = RANGES[key];
    if (!range) return value;

    if (range.kind === "bool") {
        if (value === true) return 1;
        if (typeof value === "number") return value !== 0 ? 1 : 0;
        var flag = String(value).trim().toLowerCase();
        return (flag === "1" || flag === "true" || flag === "on" || flag === "yes") ? 1 : 0;
    }

    var n = Number(value);
    if (!isFinite(n)) return range.default;
    if (range.kind === "int") n = Math.round(n);
    if (n < range.min) n = range.min;
    if (n > range.max) n = range.max;
    // Avoid float noise from arithmetic (0.30000000000000004).
    return Math.round(n * 1000000) / 1000000;
}
