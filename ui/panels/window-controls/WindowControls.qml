import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../../core/EffectRanges.js" as EffectRanges
import "../../bar"

Item {
    id: window

    Colors { id: _theme }

    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0 || "#6c7086"
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue || "#89b4fa"
    readonly property color green: _theme.green || "#a6e3a1"
    readonly property color peach: _theme.peach || "#fab387"
    readonly property color sapphire: _theme.sapphire || "#74c7ec"
    readonly property color red: _theme.red || "#f38ba8"

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val) }

    // The 12 knobs live in the shared HyprEffects singleton (same kernel as
    // the BarEditor Hyprland tab): robust live read + partial live apply.
    readonly property var fx: HyprEffects.values

    property bool isDirty: false

    // Re-read the live values every time the widget opens; persist the Lua
    // overrides on close (one Hyprland auto-reload, not one per knob).
    Component.onCompleted: HyprEffects.refresh()
    Component.onDestruction: HyprEffects.persist()

    // Changes preview live (debounced) through HyprEffects; Save persists the
    // Lua overrides now and clears the dirty dot.
    function saveChanges() {
        HyprEffects.persist()
        window.isDirty = false
    }

    function resetDefaults() {
        HyprEffects.resetEffects()
        window.isDirty = true
    }

    function markDirty() { window.isDirty = true }

    // 0.57 blur variant cycle (wraps around the 11 enum entries).
    function cycleVariant(delta) {
        let names = HyprEffects.variantNames
        let count = names ? names.length : 0
        if (count === 0) return
        let i = HyprEffects.variantIndex(fx.blur_variant)
        i = (i + delta + count) % count
        HyprEffects.set("blur_variant", HyprEffects.variantName(i))
        markDirty()
    }

    // Booleans are applied inverted from the model (the UI only emits intent).
    function toggleFlag(key) {
        HyprEffects.set(key, !fx[key])
        markDirty()
    }

    // Short cost hint colour: green low, peach medium, red high.
    function variantCostColor(name) {
        let cost = HyprEffects.variantCost(name)
        if (cost === "high") return window.red
        if (cost === "medium") return window.peach
        return window.green
    }

    Rectangle {
        anchors.fill: parent; color: Theme.surfaceContainerLow; radius: Theme.radiusLg

        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.gapLg; spacing: Theme.gapSm

            RowLayout {
                Layout.fillWidth: true
                Text { text: "\uF2D0  Window Effects"; font.family: "Hack Nerd Font"; font.pixelSize: s(15); font.weight: Font.Bold; color: window.text }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: s(28); Layout.preferredHeight: s(28); radius: Theme.radiusSm
                    color: window.red; opacity: window.isDirty ? 0.25 : 0.08
                    Text { anchors.centerIn: parent; text: "\uF0E2"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); color: window.red; opacity: window.isDirty ? 1.0 : 0.4 }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: resetDefaults() }
                }
                Rectangle {
                    Layout.preferredWidth: s(56); Layout.preferredHeight: s(28); radius: Theme.radiusSm
                    color: window.green; opacity: window.isDirty ? 0.85 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    RowLayout { anchors.centerIn: parent; spacing: Theme.gapXs
                        Text { text: "\uF0C7"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); color: window.isDirty ? window.crust : window.green }
                        Text { text: "Save"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); font.weight: Font.Bold; color: window.isDirty ? window.crust : window.green }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (window.isDirty) saveChanges() }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: s(1);                 color: Theme.outlineVariant; opacity: 0.25 }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF06E"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.mauve; Layout.preferredWidth: s(20) }
                Text { text: "Active Opacity"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: aoDs; from: 0.3; to: 1.0; step: 0.05; initial: fx.active_opacity; barColor: window.mauve
                    onDragged: function(v) { HyprEffects.set("active_opacity", v); markDirty() }
                }
                Text { text: aoDs.current.toFixed(2); font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF070"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.blue; Layout.preferredWidth: s(20) }
                Text { text: "Inactive Opacity"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: ioDs; from: 0.3; to: 1.0; step: 0.05; initial: fx.inactive_opacity; barColor: window.blue
                    onDragged: function(v) { HyprEffects.set("inactive_opacity", v); markDirty() }
                }
                Text { text: ioDs.current.toFixed(2); font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: s(1);                 color: Theme.outlineVariant; opacity: 0.2 }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF192"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.green; Layout.preferredWidth: s(20) }
                Text { text: "Rounding"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: roDs
                    from: EffectRanges.RANGES.rounding.min
                    to: EffectRanges.RANGES.rounding.max
                    step: EffectRanges.RANGES.rounding.step
                    initial: fx.rounding; barColor: window.green
                    onDragged: function(v) { HyprEffects.set("rounding", v); markDirty() }
                }
                Text { text: Math.round(roDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: s(1);                 color: Theme.outlineVariant; opacity: 0.2 }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF0EB"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.peach; Layout.preferredWidth: s(20) }
                Text { text: "Blur Size"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: bsDs
                    from: EffectRanges.RANGES.blur_size.min
                    to: EffectRanges.RANGES.blur_size.max
                    step: EffectRanges.RANGES.blur_size.step
                    initial: fx.blur_size; barColor: window.peach
                    onDragged: function(v) { HyprEffects.set("blur_size", v); markDirty() }
                }
                Text { text: Math.round(bsDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF2C8"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.sapphire; Layout.preferredWidth: s(20) }
                Text { text: "Blur Passes"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: bpDs
                    from: EffectRanges.RANGES.blur_passes.min
                    to: EffectRanges.RANGES.blur_passes.max
                    step: EffectRanges.RANGES.blur_passes.step
                    initial: fx.blur_passes; barColor: window.sapphire
                    onDragged: function(v) { HyprEffects.set("blur_passes", v); markDirty() }
                }
                Text { text: Math.round(bpDs.current); font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            // 0.57-only blur controls (hidden on <= 0.56).
            RowLayout { visible: HyprEffects.supports057; Layout.fillWidth: true; Layout.preferredHeight: s(40); spacing: Theme.gapSm
                Text { text: "\uF2C8"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.sapphire; Layout.preferredWidth: s(20) }
                Text { text: "Blur Variant"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(88) }
                CycleButton { glyph: "\uF104"; accent: window.sapphire; onActivated: cycleVariant(-1) }
                Text {
                    text: fx.blur_variant
                    font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold
                    color: window.text; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                CycleButton { glyph: "\uF105"; accent: window.sapphire; onActivated: cycleVariant(1) }
                Text {
                    text: HyprEffects.variantCost(fx.blur_variant) + " cost"
                    font.family: "Hack Nerd Font"; font.pixelSize: s(9)
                    color: window.variantCostColor(fx.blur_variant)
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: s(66)
                }
            }

            RowLayout { visible: HyprEffects.supports057; Layout.fillWidth: true; Layout.preferredHeight: s(38); spacing: Theme.gapSm
                Text { text: "\uF0C1"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.peach; Layout.preferredWidth: s(20) }
                Text { text: "Proportional Blur"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.fillWidth: true }
                TogglePill { checked: fx.blur_proportional; accent: window.peach; onToggled: toggleFlag("blur_proportional") }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: s(1);                 color: Theme.outlineVariant; opacity: 0.2 }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF239"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.mauve; Layout.preferredWidth: s(20) }
                Text { text: "Gaps In"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: giDs
                    from: EffectRanges.RANGES.gaps_in.min
                    to: EffectRanges.RANGES.gaps_in.max
                    step: EffectRanges.RANGES.gaps_in.step
                    initial: fx.gaps_in; barColor: window.mauve
                    onDragged: function(v) { HyprEffects.set("gaps_in", v); markDirty() }
                }
                Text { text: Math.round(giDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF108"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.blue; Layout.preferredWidth: s(20) }
                Text { text: "Gaps Out"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: goDs
                    from: EffectRanges.RANGES.gaps_out.min
                    to: EffectRanges.RANGES.gaps_out.max
                    step: EffectRanges.RANGES.gaps_out.step
                    initial: fx.gaps_out; barColor: window.blue
                    onDragged: function(v) { HyprEffects.set("gaps_out", v); markDirty() }
                }
                Text { text: Math.round(goDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF358"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.peach; Layout.preferredWidth: s(20) }
                Text { text: "Border Width"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: bwDs
                    from: EffectRanges.RANGES.border_size.min
                    to: EffectRanges.RANGES.border_size.max
                    step: EffectRanges.RANGES.border_size.step
                    initial: fx.border_size; barColor: window.peach
                    onDragged: function(v) { HyprEffects.set("border_size", v); markDirty() }
                }
                Text { text: Math.round(bwDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: s(1);                 color: Theme.outlineVariant; opacity: 0.2 }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF042"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.peach; Layout.preferredWidth: s(20) }
                Text { text: "Shadow Range"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: srDs
                    from: EffectRanges.RANGES.shadow_range.min
                    to: EffectRanges.RANGES.shadow_range.max
                    step: EffectRanges.RANGES.shadow_range.step
                    initial: fx.shadow_range; barColor: window.peach
                    onDragged: function(v) { HyprEffects.set("shadow_range", v); markDirty() }
                }
                Text { text: Math.round(srDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF0E7"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.sapphire; Layout.preferredWidth: s(20) }
                Text { text: "Shadow Power"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: spDs
                    from: EffectRanges.RANGES.shadow_render_power.min
                    to: EffectRanges.RANGES.shadow_render_power.max
                    step: EffectRanges.RANGES.shadow_render_power.step
                    initial: fx.shadow_render_power; barColor: window.sapphire
                    onDragged: function(v) { HyprEffects.set("shadow_render_power", v); markDirty() }
                }
                Text { text: Math.round(spDs.current); font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF061"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.mauve; Layout.preferredWidth: s(20) }
                Text { text: "Shadow Offset X"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: soxDs; from: -30; to: 30; step: 1; initial: fx.shadow_offset_x; barColor: window.mauve
                    onDragged: function(v) { HyprEffects.set("shadow_offset_x", v); markDirty() }
                }
                Text { text: Math.round(soxDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: s(44); spacing: Theme.gapSm
                Text { text: "\uF063"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.green; Layout.preferredWidth: s(20) }
                Text { text: "Shadow Offset Y"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider { id: soyDs; from: -30; to: 30; step: 1; initial: fx.shadow_offset_y; barColor: window.green
                    onDragged: function(v) { HyprEffects.set("shadow_offset_y", v); markDirty() }
                }
                Text { text: Math.round(soyDs.current) + "px"; font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }

            // ── Wobble (0.57-only) ──────────────────────────────────────────
            Rectangle { visible: HyprEffects.supports057; Layout.fillWidth: true; Layout.preferredHeight: s(1); color: Theme.outlineVariant; opacity: 0.2 }

            RowLayout { visible: HyprEffects.supports057; Layout.fillWidth: true; Layout.preferredHeight: s(38); spacing: Theme.gapSm
                Text { text: "\uF0C8"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.mauve; Layout.preferredWidth: s(20) }
                Text { text: "Window Wobble"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.fillWidth: true }
                TogglePill { checked: fx.wobble_enabled; accent: window.mauve; onToggled: toggleFlag("wobble_enabled") }
            }

            RowLayout { visible: HyprEffects.supports057; Layout.fillWidth: true; Layout.preferredHeight: s(40); spacing: Theme.gapSm
                Text { text: "\uF0E7"; font.family: "Hack Nerd Font"; font.pixelSize: s(14); color: window.mauve; Layout.preferredWidth: s(20) }
                Text { text: "Wobble Intensity"; font.family: "Hack Nerd Font"; font.pixelSize: s(11); color: window.subtext0; Layout.preferredWidth: s(100) }
                DragSlider {
                    id: wiDs
                    from: EffectRanges.RANGES.wobble_intensity.min
                    to: EffectRanges.RANGES.wobble_intensity.max
                    step: EffectRanges.RANGES.wobble_intensity.step
                    initial: fx.wobble_intensity; barColor: window.mauve
                    // Disabled while wobble is off; the row stays in place so
                    // the panel does not jump when the toggle flips.
                    enabled: fx.wobble_enabled
                    opacity: fx.wobble_enabled ? 1.0 : 0.45
                    onDragged: function(v) { HyprEffects.set("wobble_intensity", v); markDirty() }
                }
                Text { text: Number(wiDs.current).toFixed(2); font.family: "Hack Nerd Font"; font.pixelSize: s(12); font.weight: Font.Bold; color: window.text; opacity: fx.wobble_enabled ? 1.0 : 0.45; Layout.preferredWidth: s(45); horizontalAlignment: Text.AlignRight }
            }
        }
    }

    component DragSlider: Rectangle {
        id: dslider
        property real from: 0; property real to: 1; property real step: 0.05
        property real initial: 0.5; property color barColor: window.mauve
        property real current: initial
        signal dragged(real val)

        Layout.fillWidth: true; Layout.preferredHeight: s(30)
        radius: Theme.radiusSm; color: Theme.surfaceContainerHigh

        Rectangle {
            id: fillBar
            height: parent.height; radius: Theme.radiusSm
            color: dslider.barColor; opacity: 0.5
            width: parent.width * ((dslider.current - dslider.from) / (dslider.to - dslider.from))
            Behavior on width { enabled: !dragArea.pressed; NumberAnimation { duration: 80 } }
        }

        Rectangle {
            id: knob
            y: (parent.height - height) / 2
            width: s(18); height: s(18); radius: width / 2
            color: dslider.barColor
            scale: dragArea.containsMouse || dragArea.pressed ? 1.2 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            x: Math.max(0, Math.min(parent.width - width, parent.width * ((dslider.current - dslider.from) / (dslider.to - dslider.from)) - width / 2))
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real startX: 0
            property real startVal: 0

            onPressed: function(mouse) {
                startX = mouse.x
                startVal = dslider.current
                updateFromMouse(mouse.x)
            }
            onPositionChanged: function(mouse) {
                if (pressed) updateFromMouse(mouse.x)
            }
            function updateFromMouse(mx) {
                let frac = Math.max(0, Math.min(1, mx / parent.width))
                let range = dslider.to - dslider.from
                let raw = dslider.from + frac * range
                let stepped = Math.round(raw / dslider.step) * dslider.step
                stepped = Math.max(dslider.from, Math.min(dslider.to, stepped))
                dslider.current = stepped
                dslider.dragged(stepped)
            }
        }
    }

    // Small chevron button for the 0.57 variant cycle.
    component CycleButton: Rectangle {
        id: cbtn
        property string glyph: ""
        property color accent: window.sapphire
        signal activated()

        Layout.preferredWidth: s(24); Layout.preferredHeight: s(24)
        Layout.alignment: Qt.AlignVCenter
        radius: Theme.radiusSm
        color: cbMa.containsMouse ? Theme.stateLayer(cbtn.accent, Theme.stateHover) : Theme.surfaceContainerHigh
        border.width: 1
        border.color: cbMa.containsMouse ? cbtn.accent : Theme.outlineVariant
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: cbtn.glyph
            font.family: "Hack Nerd Font"
            font.pixelSize: s(11)
            color: window.text
        }
        MouseArea {
            id: cbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cbtn.activated()
        }
    }

    // Compact on/off pill used by the 0.57 blur/wobble rows.
    component TogglePill: Rectangle {
        id: tpill
        property bool checked: false
        property color accent: window.mauve
        signal toggled()

        Layout.preferredWidth: s(40); Layout.preferredHeight: s(22)
        Layout.alignment: Qt.AlignVCenter
        radius: height / 2
        color: tpill.checked ? tpill.accent : Theme.surfaceContainer
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: tpill.height - s(4)
            height: width
            radius: width / 2
            color: tpill.checked ? window.crust : window.text
            x: tpill.checked ? tpill.width - width - s(2) : s(2)
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tpill.toggled()
        }
    }
}
