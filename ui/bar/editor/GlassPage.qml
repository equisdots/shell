import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../edit"
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// GlassPage — BarEditor tab (Theme group): glassmorphism for popups, menus
// and the bar.
//
// The backdrop blur itself is a Hyprland layer rule (`hyprland/config/
// layers.lua`, blur = true + ignore_alpha) using the Blur Size / Passes from
// the Hyprland tab. This page edits the settings.json "glass" section, which
// the shell's Colors/Theme singletons apply as background alpha. Liquid mode
// additionally replaces card fills with the wallpaper lens. Applies live
// (settings watcher + forced palette re-apply).
//
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors).
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null

    // Same defaults the Colors/Theme singletons fall back to.
    property bool gEnabled: false
    property real gOpacity: 0.85
    property bool gLiquid: false
    property bool gPrism: false
    property bool gAurora: false
    property real gPrismIntensity: 0.60
    property real gPrismBlur: 1.25
    property real gPrismTint: 1.35
    property real gPrismShade: 1.20
    property real gPrismBrightness: 0.35
    property real gAuroraTint: 0.75
    property real gAuroraSheen: 0.85

    readonly property var flickable: body.item ? body.item.flickable : null

    function syncFromConfig() {
        // Live source: the editor's Colors instance watches settings.json, so
        // external edits are reflected too (Config is read once at startup).
        let s = (root.bar && root.bar.colors && root.bar.colors.glassSettings)
                ? root.bar.colors.glassSettings : {};
        root.gEnabled = s.enabled === true;
        root.gOpacity = s.opacity !== undefined ? s.opacity : 0.85;
        root.gLiquid = s.liquid === true;
        root.gPrism = s.prism === true;
        root.gAurora = s.aurora === true;
        root.gPrismIntensity = s.prismIntensity !== undefined ? s.prismIntensity : 0.60;
        root.gPrismBlur = s.prismBlur !== undefined ? s.prismBlur : 1.25;
        root.gPrismTint = s.prismTint !== undefined ? s.prismTint : 1.35;
        root.gPrismShade = s.prismShade !== undefined ? s.prismShade : 1.20;
        root.gPrismBrightness = s.prismBrightness !== undefined ? s.prismBrightness : 0.35;
        root.gAuroraTint = s.auroraTint !== undefined ? s.auroraTint : 0.75;
        root.gAuroraSheen = s.auroraSheen !== undefined ? s.auroraSheen : 0.85;
    }
    Component.onCompleted: root.syncFromConfig()

    // Debounced commit into settings.json "glass" (drag friendly).
    property var _pending: ({})
    Timer { id: saveTimer; interval: 300; onTriggered: root.flush() }
    function set(key, v) {
        root._pending[key] = v;
        saveTimer.restart();
    }
    function flush() {
        let keys = Object.keys(root._pending);
        if (keys.length === 0) return;
        let base = (root.bar && root.bar.colors && root.bar.colors.glassSettings)
                   ? root.bar.colors.glassSettings : {};
        Config.setSetting("glass", Object.assign({}, base, root._pending));
        root._pending = {};
    }
    Component.onDestruction: root.flush()

    Loader {
        id: body
        anchors.fill: parent
        active: root.bar !== null
        sourceComponent: pageBody
    }

    Component {
        id: pageBody
        Item {
            anchors.fill: parent
            property alias flickable: pageFlick

            Flickable {
                id: pageFlick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: pageCol.height + bar.s(Theme.gapLg)
                ScrollBar.vertical: ScrollBar {
                    id: vScroll
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || vScroll.hovered
                    contentItem: Rectangle {
                        radius: bar.s(Theme.radiusXs)
                        color: Theme.surfaceContainerHighest
                        opacity: vScroll.active ? 1.0 : 0.45
                    }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(Theme.gapSm)
                    y: bar.s(Theme.gapSm)
                    width: pageFlick.width - bar.s(Theme.gapLg)
                    spacing: bar.s(Theme.gapLg)

                    Text {
                        text: "Glass"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Translucent backgrounds for popups, menus and the bar. Enable liquid glass to use the wallpaper lens across the shell; these cards then step aside so borders and type sit on the lens. The compositor blur rule stays available for the standard mode."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "\uF853"
                        label: "Enabled"
                        checked: root.gEnabled
                        onToggled: { root.gEnabled = !root.gEnabled; root.set("enabled", root.gEnabled); }
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "\uF0C4"
                        label: "Liquid glass (wallpaper lens)"
                        checked: root.gLiquid
                        onToggled: {
                            root.gLiquid = !root.gLiquid;
                            if (root.gLiquid) {
                                root.gPrism = false; root.set("prism", false);
                                root.gAurora = false; root.set("aurora", false);
                            }
                            root.set("liquid", root.gLiquid);
                        }
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "\uF06E"
                        label: "Prism glass (refractive lens)"
                        checked: root.gPrism
                        onToggled: {
                            root.gPrism = !root.gPrism;
                            if (root.gPrism) {
                                root.gLiquid = false; root.set("liquid", false);
                                root.gAurora = false; root.set("aurora", false);
                            }
                            root.set("prism", root.gPrism);
                        }
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "\uF0C4"
                        label: "Aurora glass (Apple-style)"
                        checked: root.gAurora
                        onToggled: {
                            root.gAurora = !root.gAurora;
                            if (root.gAurora) {
                                root.gLiquid = false; root.set("liquid", false);
                                root.gPrism = false; root.set("prism", false);
                            }
                            root.set("aurora", root.gAurora);
                        }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gAurora
                        icon: "\uF0EB"
                        label: "Aurora tint"
                        from: 0.25; to: 1.8; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.peach
                        value: root.gAuroraTint
                        onEdited: (v) => { root.gAuroraTint = v; root.set("auroraTint", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gAurora
                        icon: "\uF185"
                        label: "Aurora sheen"
                        from: 0.0; to: 1.5; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.yellow
                        value: root.gAuroraSheen
                        onEdited: (v) => { root.gAuroraSheen = v; root.set("auroraSheen", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gPrism
                        icon: "\uF0D0"
                        label: "Prism intensity"
                        from: 0.15; to: 1.5; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.mauve
                        value: root.gPrismIntensity
                        onEdited: (v) => { root.gPrismIntensity = v; root.set("prismIntensity", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gPrism
                        icon: "\uF0C5"
                        label: "Prism blur"
                        from: 0.3; to: 2.5; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.blue
                        value: root.gPrismBlur
                        onEdited: (v) => { root.gPrismBlur = v; root.set("prismBlur", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gPrism
                        icon: "\uF53F"
                        label: "Prism tint"
                        from: 0.3; to: 2.2; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.peach
                        value: root.gPrismTint
                        onEdited: (v) => { root.gPrismTint = v; root.set("prismTint", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gPrism
                        icon: "\uF0EB"
                        label: "Prism shade"
                        from: 0.0; to: 1.8; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.green
                        value: root.gPrismShade
                        onEdited: (v) => { root.gPrismShade = v; root.set("prismShade", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        visible: root.gPrism
                        icon: "\uF185"
                        label: "Prism brightness"
                        from: 0.0; to: 1.2; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.yellow
                        value: root.gPrismBrightness
                        onEdited: (v) => { root.gPrismBrightness = v; root.set("prismBrightness", v); }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        icon: "\uF06E"
                        label: "Background opacity"
                        from: 0.4; to: 1.0; step: 0.05
                        decimals: 2
                        accentColor: bar.colors.mauve
                        value: root.gOpacity
                        onEdited: (v) => { root.gOpacity = v; root.set("opacity", v); }
                    }

                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: root.gPrism
                            ? "Prism glass adds crystal facets and chromatic separation. Lower brightness and raise tint when the wallpaper fights the text; Prism blur softens the refracted image."
                            : (root.gAurora
                                ? "Aurora uses the Prism optics as a base with a soft top light band and no hard rim lines. It has no internal edges; adjust tint and sheen for readability."
                                : (root.gLiquid
                                    ? "Liquid glass samples the current wallpaper and bends it at the surface edge. It is lighter than Prism and preserves the current shell look."
                                    : (root.gEnabled
                                        ? "Lower values = more see-through (less contrast). 0.80-0.90 is a good balance with palette backgrounds."
                                        : "Enable to apply background alpha; the compositor blur rule stays loaded but is invisible while backgrounds are opaque.")))
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
