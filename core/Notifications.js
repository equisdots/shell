.pragma library
// ═══════════════════════════════════════════════════════════════════════════
// shell · core — Notifications
//
// Personalization API for the notification popups: pure helpers that
// normalize the "notifications" settings section and produce the scaled
// layout. The UI consumes it; nothing here touches QML objects.
// ═══════════════════════════════════════════════════════════════════════════
var DEFAULTS = {
    width: 350,       // popup width (unscaled)
    marginTop: 60,
    marginRight: 20,
    spacing: 12,
    radius: 14,
    padding: 12,
    timeout: 5000,    // ms for notifications without an explicit timeout (0 = never)
    maxVisible: 3     // how many popups stay on screen (0 = no limit)
};

// Normalized section: every known option with a valid value (defaults fill in).
function normalize(raw) {
    let out = {};
    let src = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    for (let key in DEFAULTS) {
        let v = src[key];
        out[key] = (typeof v === "number" && v >= 0) ? v : DEFAULTS[key];
    }
    return out;
}

// Scaled layout for the popup window (scale comes from core/WindowRegistry).
function layout(raw, scale) {
    let o = normalize(raw);
    return {
        w: Math.round(o.width * scale),
        marginTop: Math.round(o.marginTop * scale),
        marginRight: Math.round(o.marginRight * scale),
        spacing: Math.round(o.spacing * scale),
        radius: Math.round(o.radius * scale),
        padding: Math.round(o.padding * scale)
    };
}

function defaultTimeout(raw) {
    return normalize(raw).timeout;
}

function maxVisible(raw) {
    return normalize(raw).maxVisible;
}

// New section with one option changed (for the editor / API users).
function setOption(raw, key, value) {
    let out = normalize(raw);
    if (DEFAULTS.hasOwnProperty(key)) out[key] = value;
    return out;
}
