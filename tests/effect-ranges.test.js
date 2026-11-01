#!/usr/bin/env node
// Unit tests for core/EffectRanges.js (plain node, no dependencies).
//
// The QML `.pragma library` directive is stripped before evaluating the file
// in a vm context, the same trick scripts/check.sh uses for syntax checks.
//
// Usage: node tests/effect-ranges.test.js

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const file = path.join(__dirname, "..", "core", "EffectRanges.js");
const source = fs
    .readFileSync(file, "utf8")
    .replace(/^[ \t]*\.pragma[^\n]*\n/, "");

const ctx = { console };
vm.createContext(ctx);
vm.runInContext(source, ctx);

const { RANGES, VARIANTS, clamp, variantIndex, variantName, variantNames } = ctx;

let passed = 0;
let failed = 0;

function check(name, fn) {
    try {
        fn();
        passed++;
    } catch (err) {
        failed++;
        console.error("FAIL: " + name + " — " + err.message);
    }
}

function eq(actual, expected, label) {
    if (actual !== expected) {
        throw new Error((label || "value") + ": expected " + JSON.stringify(expected)
            + ", got " + JSON.stringify(actual));
    }
}

// ── RANGES ────────────────────────────────────────────────────────────────
check("RANGES is an object", () => {
    if (!RANGES || typeof RANGES !== "object") throw new Error("missing RANGES");
});

const requiredKeys = [
    "active_opacity", "inactive_opacity", "rounding", "blur_size", "blur_passes",
    "gaps_in", "gaps_out", "border_size", "shadow_range", "shadow_render_power",
    "shadow_offset_x", "shadow_offset_y", "blur_proportional", "wobble_intensity"
];

check("RANGES covers every effect key", () => {
    const missing = requiredKeys.filter((k) => !RANGES[k]);
    if (missing.length) throw new Error("missing keys: " + missing.join(", "));
});

check("RANGES entries have min/max/step/default", () => {
    for (const key of requiredKeys) {
        const r = RANGES[key];
        for (const field of ["min", "max", "step", "default"]) {
            if (typeof r[field] !== "number" || !isFinite(r[field]))
                throw new Error(key + "." + field + " is not a finite number");
        }
        if (r.min > r.max) throw new Error(key + ": min > max");
    }
});

check("0.57 ranges", () => {
    eq(RANGES.rounding.min, 0, "rounding.min");
    eq(RANGES.rounding.max, 100, "rounding.max");
    eq(RANGES.shadow_range.max, 100, "shadow_range.max");
    eq(RANGES.shadow_render_power.min, 1, "shadow_render_power.min");
    eq(RANGES.shadow_render_power.max, 4, "shadow_render_power.max");
    eq(RANGES.border_size.max, 20, "border_size.max");
    eq(RANGES.blur_passes.max, 10, "blur_passes.max");
    eq(RANGES.wobble_intensity.min, 0, "wobble_intensity.min");
    eq(RANGES.wobble_intensity.max, 2, "wobble_intensity.max");
});

check("comfortable defaults", () => {
    eq(RANGES.active_opacity.default, 0.85, "active_opacity");
    eq(RANGES.inactive_opacity.default, 0.80, "inactive_opacity");
    eq(RANGES.rounding.default, 20, "rounding");
    eq(RANGES.blur_size.default, 8, "blur_size");
    eq(RANGES.blur_passes.default, 3, "blur_passes");
    eq(RANGES.gaps_in.default, 16, "gaps_in");
    eq(RANGES.gaps_out.default, 25, "gaps_out");
    eq(RANGES.border_size.default, 2, "border_size");
    eq(RANGES.shadow_range.default, 35, "shadow_range");
    eq(RANGES.shadow_render_power.default, 4, "shadow_render_power");
    eq(RANGES.shadow_offset_x.default, 0, "shadow_offset_x");
    eq(RANGES.shadow_offset_y.default, 10, "shadow_offset_y");
    eq(RANGES.blur_proportional.default, 0, "blur_proportional");
    eq(RANGES.wobble_intensity.default, 0.2, "wobble_intensity");
});

// ── clamp ─────────────────────────────────────────────────────────────────
check("clamp ints to the 0.57 ranges", () => {
    eq(clamp("rounding", 500), 100, "rounding high");
    eq(clamp("rounding", -5), 0, "rounding low");
    eq(clamp("rounding", 42.6), 43, "rounding rounds");
    eq(clamp("shadow_range", 999), 100, "shadow_range high");
    eq(clamp("shadow_range", -1), 0, "shadow_range low");
    eq(clamp("shadow_render_power", 99), 4, "render_power high");
    eq(clamp("shadow_render_power", 0), 1, "render_power low");
    eq(clamp("border_size", 99), 20, "border_size high");
    eq(clamp("blur_passes", 99), 10, "blur_passes high");
    eq(clamp("blur_passes", -3), 0, "blur_passes low");
    eq(clamp("blur_size", 999), 100, "blur_size high");
    eq(clamp("shadow_offset_x", 999), 100, "offset x high");
    eq(clamp("shadow_offset_x", -999), -100, "offset x low");
});

check("clamp floats", () => {
    eq(clamp("active_opacity", 5), 1, "opacity high");
    eq(clamp("active_opacity", -2), 0, "opacity low");
    eq(clamp("inactive_opacity", 0.5), 0.5, "opacity inside");
    eq(clamp("wobble_intensity", 99), 2, "wobble high");
    eq(clamp("wobble_intensity", -1), 0, "wobble low");
    eq(clamp("wobble_intensity", 0.35), 0.35, "wobble inside");
});

check("clamp falls back to defaults on invalid input", () => {
    eq(clamp("rounding", "not-a-number"), RANGES.rounding.default, "rounding");
    eq(clamp("wobble_intensity", undefined), RANGES.wobble_intensity.default, "wobble");
    eq(clamp("shadow_render_power", NaN), RANGES.shadow_render_power.default, "render_power");
});

check("clamp booleans to 0/1", () => {
    eq(clamp("blur_proportional", true), 1, "true");
    eq(clamp("blur_proportional", false), 0, "false");
    eq(clamp("blur_proportional", "1"), 1, "string 1");
    eq(clamp("blur_proportional", "true"), 1, "string true");
    eq(clamp("wobble_enabled", 0), 0, "number 0");
    eq(clamp("wobble_enabled", 7), 1, "number 7");
});

check("clamp canonicalises blur_variant", () => {
    eq(clamp("blur_variant", "aurora"), "aurora", "known name");
    eq(clamp("blur_variant", "Heat-Shimmer"), "heat_shimmer", "dash spelling");
    eq(clamp("blur_variant", "7"), "heat_shimmer", "numeric string");
    eq(clamp("blur_variant", 10), "haze", "numeric index");
    eq(clamp("blur_variant", "definitely-not-a-variant"), "kawase", "invalid");
    eq(clamp("blur_variant", null), "kawase", "null");
});

check("clamp passes unknown keys through", () => {
    eq(clamp("not_a_key", 123), 123, "unknown");
});

// ── VARIANTS ──────────────────────────────────────────────────────────────
check("VARIANTS has the 11 Hyprland entries in order", () => {
    const expected = [
        "kawase", "frost", "ripple", "drops", "water", "fluid_jar",
        "prism", "heat_shimmer", "acrylic", "aurora", "haze"
    ];
    eq(VARIANTS.length, 11, "count");
    for (let i = 0; i < expected.length; i++) {
        eq(VARIANTS[i].index, i, "index " + i);
        eq(VARIANTS[i].name, expected[i], "name " + i);
        eq(variantName(i), expected[i], "variantName(" + i + ")");
        eq(variantIndex(expected[i]), i, "variantIndex(" + expected[i] + ")");
    }
});

check("variantNames returns a plain ordered list", () => {
    const names = variantNames();
    eq(names.length, 11, "count");
    eq(names[0], "kawase", "first");
    eq(names[10], "haze", "last");
});

check("variantIndex clamps unknown input to kawase", () => {
    eq(variantIndex("nope"), 0, "unknown name");
    eq(variantIndex(99), 10, "high index");
    eq(variantIndex(-5), 0, "low index");
    eq(variantName(99), "haze", "high name");
});

check("cost flags mark the expensive animated variants", () => {
    const byName = {};
    for (const v of VARIANTS) byName[v.name] = v;
    eq(byName.kawase.cost, "low", "kawase cost");
    eq(byName.frost.animated, false, "frost animated");
    for (const name of ["ripple", "water", "fluid_jar", "heat_shimmer", "aurora", "haze"]) {
        eq(byName[name].animated, true, name + " animated");
        eq(byName[name].cost, "high", name + " cost");
    }
    for (const v of VARIANTS) {
        if (typeof v.hint !== "string" || v.hint.length === 0)
            throw new Error(v.name + ": missing hint");
    }
});

// ── summary ───────────────────────────────────────────────────────────────
console.log("effect-ranges: " + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
