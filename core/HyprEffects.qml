pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "EffectRanges.js" as EffectRanges

// ═══════════════════════════════════════════════════════════════════════════
// HyprEffects — shared state for the window-effect knobs.
//
// Single source for the BarEditor Hyprland tab and the Window Controls
// widget (SUPER+SHIFT+B). Talks to core/scripts/hypr-effects.sh:
//   · refresh()  reads the live values (hyprctl -j, robust parsing: gaps
//                arrive as "css gap data", not "int:").
//   · set(k,v)   applies ONLY that knob (JSON state + .lua + live
//                `hyprctl eval`, no reload) with drag debounce.
//
// The old flow had one reader per UI (both with parsing bugs) and rewrote all
// 12 knobs together: one change clobbered the rest. Now there is a single
// reader and a single partial writer.
//
// Hyprland 0.57 adds blur variants, proportional blur and window wobble. The
// script probes for them and reports supports_057; the 0.57-only rows in the
// UIs stay hidden on older compositors, and the script never writes those
// keys to the generated Lua on <= 0.56.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/scripts/hypr-effects.sh"

    // True when the kernel probed Hyprland 0.57+ (decoration:blur:variant
    // exists). Read from the script on every refresh().
    property bool supports057: false

    // Same keys as window-effects.json (see SPECS in the script). Defaults are
    // the comfortable/low-cost values: kawase, wobble off, intensity 0.2.
    property var values: ({
        active_opacity: 0.85,
        inactive_opacity: 0.80,
        rounding: 20,
        blur_enabled: true,
        blur_size: 8,
        blur_passes: 3,
        gaps_in: 16,
        gaps_out: 25,
        border_size: 2,
        shadow_enabled: true,
        shadow_range: 35,
        shadow_render_power: 4,
        shadow_offset_x: 0,
        shadow_offset_y: 10,
        dim_inactive: true,
        // 0.57-only.
        blur_variant: "kawase",
        blur_proportional: false,
        wobble_enabled: false,
        wobble_intensity: 0.2
    })

    // Variant helpers for the cycle controls, backed by the shared table.
    readonly property var variantNames: EffectRanges.variantNames()
    function variantIndex(name) { return EffectRanges.variantIndex(name); }
    function variantName(index) { return EffectRanges.variantName(index); }
    function variantHint(name) { return EffectRanges.variantHint(name); }
    function variantCost(name) { return EffectRanges.variantCost(name); }

    function get(key) { return root.values[key]; }

    // Hyprland 0.57 rejects out-of-range values (including
    // decoration:shadow:render_power, 1..4), so clamp at the single UI
    // boundary using the shared table.
    function _clamp(key, v) {
        return EffectRanges.clamp(key, v);
    }

    // Re-read the live values (when each UI opens and on demand).
    function refresh() { reader.running = true; }

    Process {
        id: reader
        command: ["bash", root.scriptPath, "read"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                let next = {};
                for (let k in root.values) next[k] = root.values[k];
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let eq = lines[i].indexOf("=");
                    if (eq < 0) continue;
                    let key = lines[i].slice(0, eq).trim();
                    let raw = lines[i].slice(eq + 1).trim();
                    if (key === "supports_057") {
                        root.supports057 = (raw === "1");
                        continue;
                    }
                    if (!(key in next)) continue;
                    if (key === "blur_variant") {
                        next[key] = EffectRanges.variantName(EffectRanges.variantIndex(raw));
                    } else if (key === "blur_proportional" || key === "wobble_enabled") {
                        next[key] = (raw === "1" || raw === "true");
                    } else {
                        let num = parseFloat(raw);
                        if (!isNaN(num)) next[key] = root._clamp(key, num);
                    }
                }
                root.values = next;
            }
        }
    }

    // Booleans travel as 0/1 through the shell kernel.
    function _serialize(key, value) {
        if (key === "blur_proportional" || key === "wobble_enabled"
                || key === "blur_enabled" || key === "shadow_enabled"
                || key === "dim_inactive")
            return key + "=" + (value ? "1" : "0");
        return key + "=" + value;
    }

    // Preview with drag debounce: touched keys accumulate and 200 ms later a
    // single `preview key=val ...` is sent — JSON + live eval, NO Lua writes.
    // Rewriting the Lua overrides makes Hyprland auto-reload its config (the
    // visible "all windows restart" while dragging), so they are only written
    // on persist().
    property var _pending: ({})
    property var _changed: ({})
    Timer {
        id: flushTimer
        interval: 200
        onTriggered: root.flush()
    }
    function set(key, v) {
        if (!(key in root.values)) return;
        if (key === "blur_variant") {
            if (typeof v !== "string") return;
            v = EffectRanges.clamp(key, v);
        } else if (key === "blur_proportional" || key === "wobble_enabled"
                || key === "blur_enabled" || key === "shadow_enabled"
                || key === "dim_inactive") {
            v = !!v;
        } else {
            if (typeof v !== "number" || isNaN(v)) return;
            v = root._clamp(key, v);
        }
        if (root.values[key] === v) return;
        let next = {};
        for (let k in root.values) next[k] = root.values[k];
        next[key] = v;
        root.values = next;
        root._pending[key] = v;
        root._changed[key] = v;
        flushTimer.restart();
    }
    // Apply pending previews now (live, no reload).
    function flush() {
        let args = [];
        for (let k in root._pending) args.push(root._serialize(k, root._pending[k]));
        root._pending = {};
        if (args.length === 0) return;
        Quickshell.execDetached(["bash", root.scriptPath, "preview"].concat(args));
    }
    // Write the Lua overrides once (called when the UI closes / Save): this
    // triggers a single Hyprland auto-reload, never one per knob movement.
    function persist() {
        let args = [];
        for (let k in root._changed) args.push(root._serialize(k, root._changed[k]));
        root._pending = {};
        root._changed = {};
        if (args.length === 0) return;
        Quickshell.execDetached(["bash", root.scriptPath, "apply"].concat(args));
    }

    // Reset defaults: effects only (gaps and border untouched, same as the
    // original reset of both UIs). 0.57-only knobs go back to the comfortable
    // values: kawase, proportional blur off, wobble off at 0.2.
    function resetEffects() {
        root.set("active_opacity", 0.85);
        root.set("inactive_opacity", 0.80);
        root.set("rounding", 20);
        root.set("blur_enabled", true);
        root.set("blur_size", 8);
        root.set("blur_passes", 3);
        root.set("shadow_enabled", true);
        root.set("shadow_range", 35);
        root.set("shadow_render_power", 4);
        root.set("shadow_offset_x", 0);
        root.set("shadow_offset_y", 10);
        root.set("dim_inactive", true);
        root.set("blur_variant", "kawase");
        root.set("blur_proportional", false);
        root.set("wobble_enabled", false);
        root.set("wobble_intensity", 0.2);
        root.flush();
    }

    Component.onCompleted: root.refresh()
}
