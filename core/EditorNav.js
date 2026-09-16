.pragma library
// ═══════════════════════════════════════════════════════════════════════════
// shell · core — EditorNav
//
// Navigation model for the Settings panel (BarEditor): coherent groups of
// pages, each collapsible/expandable, reorderable and overridable from
// settings.json under "editor". Nothing here touches QML objects; the panel
// renders whatever this module returns.
//
// settings.json:
//   "editor": {
//     "collapsed": { "bar": true, ... },      // per-group collapse state
//     "defaultPage": "s_general",
//     "order": ["shell", "bar", "theme", "behavior", "system"],
//     "hidden": ["d_guide"]
//   }
// ═══════════════════════════════════════════════════════════════════════════
var GROUPS = [
    {
        id: "shell",
        label: "Shell",
        icon: "󰒓",
        items: [
            { id: "s_general",  icon: "󰒓", label: "General" },
            { id: "s_weather",  icon: "󰖐", label: "Weather" },
            { id: "s_keyboard", icon: "󰌌", label: "Keyboard" },
            { id: "s_monitors", icon: "󰍹", label: "Monitors" },
            { id: "s_startup",  icon: "󰐥", label: "Startup" }
        ]
    },
    {
        id: "bar",
        label: "Bar",
        icon: "󰮯",
        items: [
            { id: "d_engine",     icon: "󰮯", label: "Engine" },
            { id: "d_position",   icon: "󱂬", label: "Position" },
            { id: "d_style",      icon: "󰏘", label: "Style",      engine: "bar" },
            { id: "d_zones",      icon: "󰮯", label: "Zones",      engine: "bar" },
            { id: "d_classic",    icon: "󰹑", label: "Classic Bar", engine: "classic" },
            { id: "d_modules",    icon: "󰍜", label: "Modules" },
            { id: "d_workspaces", icon: "󰠰", label: "Workspaces" }
        ]
    },
    {
        id: "theme",
        label: "Theme",
        icon: "✦",
        items: [
            { id: "d_palette",    icon: "✦", label: "Palette" },
            { id: "d_animations", icon: "󰔟", label: "Animations" }
        ]
    },
    {
        id: "behavior",
        label: "Behavior",
        icon: "󰀻",
        items: [
            { id: "d_launcher",      icon: "󰀻", label: "Launcher" },
            { id: "d_notifications", icon: "󰂚", label: "Notifications" }
        ]
    },
    {
        id: "system",
        label: "System",
        icon: "󰣇",
        items: [
            { id: "d_hyprland", icon: "󰣇", label: "Hyprland" },
            { id: "d_input",    icon: "󰌌", label: "Input" },
            { id: "d_gpu",      icon: "󰢮", label: "GPU" },
            { id: "d_idle",     icon: "󰒲", label: "Idle" },
            { id: "d_guide",    icon: "󰅖", label: "About" }
        ]
    }
];

function groups() {
    let out = [];
    for (let i = 0; i < GROUPS.length; i++) {
        let g = GROUPS[i];
        let items = [];
        for (let j = 0; j < g.items.length; j++) {
            let it = {};
            for (let k in g.items[j]) it[k] = g.items[j][k];
            items.push(it);
        }
        out.push({ id: g.id, label: g.label, icon: g.icon, items: items });
    }
    return out;
}

// Overrides from settings: order, hidden items, collapse state.
function configure(groups, raw) {
    let cfg = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    let hidden = Array.isArray(cfg.hidden) ? cfg.hidden : [];

    for (let i = 0; i < groups.length; i++) {
        groups[i].items = groups[i].items.filter(function (it) {
            return hidden.indexOf(it.id) === -1;
        });
        groups[i].collapsed = !!(cfg.collapsed && cfg.collapsed[groups[i].id]);
    }

    if (Array.isArray(cfg.order) && cfg.order.length) {
        let pos = function (id) {
            let idx = cfg.order.indexOf(id);
            return idx === -1 ? cfg.order.length + groups.length : idx;
        };
        groups.sort(function (a, b) { return pos(a.id) - pos(b.id); });
    }
    return groups;
}

function pageIds(groups) {
    let out = [];
    for (let i = 0; i < groups.length; i++)
        for (let j = 0; j < groups[i].items.length; j++)
            out.push(groups[i].items[j].id);
    return out;
}

function findItem(groups, pageId) {
    for (let i = 0; i < groups.length; i++)
        for (let j = 0; j < groups[i].items.length; j++)
            if (groups[i].items[j].id === pageId) return groups[i].items[j];
    return null;
}

// New "editor" section with one option changed (Config.updateJsonBulk ready).
function patch(raw, key, val) {
    let cfg = (raw && typeof raw === "object" && !Array.isArray(raw)) ? raw : {};
    let out = {};
    for (let k in cfg) {
        if (k === "collapsed" || k === "order" || k === "hidden") {
            out[k] = Array.isArray(cfg[k]) ? cfg[k].slice(0) : Object.assign({}, cfg[k]);
        } else {
            out[k] = cfg[k];
        }
    }
    if (key === "defaultPage" && typeof val === "string") {
        out.defaultPage = val;
    } else if (key === "order" && Array.isArray(val)) {
        out.order = val.slice(0);
    } else if (key === "hidden" && Array.isArray(val)) {
        out.hidden = val.slice(0);
    } else if (key === "collapsedGroup" && val && typeof val === "object") {
        if (!out.collapsed || typeof out.collapsed !== "object") out.collapsed = {};
        for (let g in val) out.collapsed[g] = !!val[g];
    }
    return { editor: out };
}
