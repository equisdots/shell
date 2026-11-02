import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../core"
import "../edit"

// ═══════════════════════════════════════════════════════════════════════════
// ProfilesPage — presets for compositor + glass cost.
//
// X is the snapshot of the author's current desktop. Performance, Balanced,
// Gaming, Focus and Cinematic are intent-based presets. Applying one writes
// the existing HyprEffects state, animations, glass and frame at once; no new
// daemon is added.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null
    readonly property var flickable: body.item ? body.item.flickable : null

    // Current live values (window-effects.json at the time this page shipped).
    readonly property var xEffects: ({
        active_opacity: 1.0, inactive_opacity: 1.0, rounding: 22,
        blur_enabled: true, blur_size: 12, blur_passes: 3,
        gaps_in: 100, gaps_out: 98, border_size: 0,
        shadow_enabled: true, shadow_range: 85, shadow_render_power: 4,
        shadow_offset_x: 30, shadow_offset_y: 30,
        blur_variant: "kawase", blur_proportional: false,
        wobble_enabled: true, wobble_intensity: 0.45,
        dim_inactive: true
    })
    readonly property var xAnimations: ({
        enabled: true, speed: 0.8, workspaceStyle: "slidevert",
        workspaceCurve: "overshot", specialStyle: "slidevert",
        workspaceWrap: false, windowStyle: "popin 80%",
        windowCurve: "overshot", windowOutStyle: "popin 80%",
        windowOutCurve: "easeOutExpo"
    })
    readonly property var xGlass: ({
        enabled: false, opacity: 0.85, liquid: false, prism: false,
        prismIntensity: 1.45, prismBlur: 2.3, prismTint: 2.2,
        prismShade: 1.8, prismBrightness: 0.55, aurora: false,
        auroraTint: 1.65, auroraSheen: 1.2
    })
    readonly property var xFrame: ({
        enabled: false, thickness: 25, sideThickness: 43, radius: 15,
        inset: -4, gap: 4, notchRadius: 7, color: "blue", alpha: 0.1,
        line: true, lineWidth: 10, fill: true, fillColor: "surface0",
        fillAlpha: 1, reserve: false, reserveExtra: 15, notchBar: true,
        notchWidget: true, notchMascot: true, layer: "bottom",
        notchHosts: true
    })

    readonly property var profiles: ({
        x: {
            label: "X", icon: "󰀵",
            effects: xEffects,
            animations: xAnimations,
            glass: xGlass,
            frame: xFrame
        },
        performance: {
            label: "Performance", icon: "󰓅",
            effects: Object.assign({}, xEffects, {
                blur_enabled: false, blur_size: 0, blur_passes: 0,
                shadow_enabled: false, shadow_range: 0,
                shadow_render_power: 1, shadow_offset_x: 0,
                shadow_offset_y: 0, wobble_enabled: false,
                dim_inactive: false, active_opacity: 1.0,
                inactive_opacity: 1.0
            }),
            animations: Object.assign({}, xAnimations, { enabled: false }),
            glass: Object.assign({}, xGlass, { enabled: false }),
            frame: Object.assign({}, xFrame, { enabled: false })
        },
        balanced: {
            label: "Balanced", icon: "󰒮",
            effects: Object.assign({}, xEffects, {
                blur_enabled: true, blur_size: 6, blur_passes: 2,
                shadow_enabled: true, shadow_range: 20,
                shadow_render_power: 3, shadow_offset_x: 0,
                shadow_offset_y: 10, wobble_enabled: false,
                dim_inactive: false
            }),
            animations: Object.assign({}, xAnimations, { enabled: true }),
            glass: Object.assign({}, xGlass, {
                enabled: true, liquid: true, prism: false, aurora: false
            }),
            frame: Object.assign({}, xFrame, { enabled: false })
        },
        gaming: {
            label: "Gaming", icon: "󰊗",
            effects: Object.assign({}, xEffects, {
                blur_enabled: false, blur_size: 0, blur_passes: 0,
                shadow_enabled: false, shadow_range: 0,
                shadow_render_power: 1, shadow_offset_x: 0,
                shadow_offset_y: 0, wobble_enabled: false,
                dim_inactive: false, active_opacity: 1.0,
                inactive_opacity: 1.0, gaps_in: 12, gaps_out: 20,
                border_size: 2, rounding: 10
            }),
            animations: Object.assign({}, xAnimations, { enabled: false }),
            glass: Object.assign({}, xGlass, { enabled: false }),
            frame: Object.assign({}, xFrame, { enabled: false })
        },
        focus: {
            label: "Focus", icon: "󰈈",
            effects: Object.assign({}, xEffects, {
                blur_enabled: true, blur_size: 8, blur_passes: 2,
                shadow_enabled: true, shadow_range: 25,
                shadow_render_power: 3, shadow_offset_x: 0,
                shadow_offset_y: 8, wobble_enabled: false,
                dim_inactive: true
            }),
            animations: Object.assign({}, xAnimations, { enabled: true, speed: 0.6 }),
            glass: Object.assign({}, xGlass, { enabled: false }),
            frame: Object.assign({}, xFrame, { enabled: false })
        },
        cinematic: {
            label: "Cinematic", icon: "󰕧",
            effects: xEffects,
            animations: Object.assign({}, xAnimations, {
                enabled: true, speed: 1.5, windowStyle: "popin 100%",
                windowCurve: "smooth", windowOutStyle: "popin 100%",
                windowOutCurve: "smooth"
            }),
            glass: Object.assign({}, xGlass, {
                enabled: true, liquid: false, prism: false, aurora: true
            }),
            frame: Object.assign({}, xFrame, { enabled: false })
        }
    })
    readonly property var profileList: [
        { id: "x", label: "X", icon: "󰀵", desc: "Exactamente la configuración actual" },
        { id: "performance", label: "Performance", icon: "󰓅", desc: "Sin blur, sombras, glass ni animaciones" },
        { id: "balanced", label: "Balanced", icon: "󰒮", desc: "Blur y sombras suaves, Glass Liquid" },
        { id: "gaming", label: "Gaming", icon: "󰊗", desc: "Máximo rendimiento y gaps compactos" },
        { id: "focus", label: "Focus", icon: "󰈈", desc: "Efectos suaves y animación rápida" },
        { id: "cinematic", label: "Cinematic", icon: "󰕧", desc: "Glass Aurora y animación lenta" }
    ]
    property string activeProfile: "x"
    Component.onCompleted: {
        let p = Config.rawSettings.performance;
        let v = (p && typeof p === "object") ? String(p.profile || "x") : "x";
        root.activeProfile = root.profiles[v] ? v : "x";
    }

    function applyProfile(id) {
        let p = root.profiles[id];
        if (!p || !root.bar) return;
        root.activeProfile = id;
        Config.setSetting("performance", { profile: id });
        for (let k in p.effects) HyprEffects.set(k, p.effects[k]);
        HyprEffects.persist();
        root.bar.applyAnimations(p.animations);
        Config.setSetting("glass", p.glass);
        Config.setSetting("frame", p.frame);
    }

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
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || hovered
                    contentItem: Rectangle {
                        radius: bar.s(Theme.radiusXs)
                        color: Theme.surfaceContainerHighest
                        opacity: active ? 0.45 : 0.45
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
                        text: "Profiles"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Un perfil aplica de golpe efectos de Hyprland, animaciones, Glass y Frame. X es tu configuración actual."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(Theme.gapMd)
                        rowSpacing: bar.s(Theme.gapMd)
                        Repeater {
                            model: root.profileList
                            delegate: OptionCard {
                                required property var modelData
                                Layout.fillWidth: true
                                bar: root.bar
                                icon: modelData.icon
                                label: modelData.label
                                active: root.activeProfile === modelData.id
                                onActivated: root.applyProfile(modelData.id)
                            }
                        }
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "X: actual. Performance: sin blur/sombras/Glass/animaciones. Balanced: blur 6/2 y Glass Liquid. Gaming: compacto y sin efectos. Focus: efectos suaves y animación rápida. Cinematic: Glass Aurora y animación lenta."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Notas"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "El perfil no toca restore-monitors ni el layout de pantallas. Los valores de efectos se guardan en window-effects.json/lua; las animaciones en user-animations.lua; Glass y Frame en settings.json."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
