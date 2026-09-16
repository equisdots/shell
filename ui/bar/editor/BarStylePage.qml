import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"

// ═══════════════════════════════════════════════════════════════════════════
// BarStylePage — BarEditor tab (bar engine only): bar look + window
// borders.
//
// Fase 5 (look Guide): títulos s(24) Black, sub-títulos s(16) Black, grids de
// OptionCards (GP:1276-1302), toggles/steppers como cards de ancho completo y
// TextField estilo card. SIN filas con cajita decorativa.
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors,
// bar.bar, bar.applyBar/applyStyle, bar.borderTargetActive, ...). NEVER
// touches ids of the editor root. Exposes the scroll Flickable via
// `flickable`. The "Window borders" controls below the Follow palette toggle
// only exist while bar.bar.borderFollowPalette === false.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent   // Phase 3: el item del Loader ocupa la stage

    property var bar: null

    // Gate: el cuerpo se crea cuando bar ya está inyectado (initial
    // property aplicada tras la creación del root). Evita bindings
    // evaluados con bar null que quedaban muertos en negro.
    readonly property var flickable: body.item ? body.item.flickable : null


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
                contentHeight: pageCol.height + bar.s(16)
                ScrollBar.vertical: ScrollBar {
                    id: vScroll
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || vScroll.hovered
                    contentItem: Rectangle {
                        radius: bar.s(2)
                        color: bar.colors.surface2
                        opacity: vScroll.active ? 1.0 : 0.45
                    }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(8)
                    y: bar.s(8)
                    width: pageFlick.width - bar.s(16)
                    spacing: bar.s(12)
                    visible: bar.engine === "bar"

                    // ════ BAR ════
                    Text {
                        text: "Bar"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    // Sub-título + presets (cards template GP:1276-1302)
                    Text {
                        text: "Style"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰍜"
                            label: "Modular"
                            active: root.bar.bar.stylePreset === "modular"
                            onActivated: root.bar.applyStyle("modular")
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰍛"
                            label: "Solid"
                            accentRole: "blue"
                            active: root.bar.bar.stylePreset === "solid"
                            onActivated: root.bar.applyStyle("solid")
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰹑"
                            label: "Fill"
                            accentRole: "teal"
                            active: root.bar.bar.stylePreset === "fill"
                            onActivated: root.bar.applyStyle("fill")
                        }
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Modular: floating islands · Solid: continuous bar · Fill: edge-to-edge strip (no gap). Presets are shortcuts — manual tweaks below stay possible."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    // Steppers numéricos (cards de ancho completo)
                    StepperCard {
                        width: parent.width
                        bar: root.bar
                        label: "Roundness"
                        value: Math.round(root.bar.bar.roundness * 100) + "%"
                        onDec: root.bar.applyBar(Object.assign({}, root.bar.bar, { roundness: Math.max(0, +(root.bar.bar.roundness - 0.1).toFixed(1)) }))
                        onInc: root.bar.applyBar(Object.assign({}, root.bar.bar, { roundness: Math.min(1, +(root.bar.bar.roundness + 0.1).toFixed(1)) }))
                    }
                    StepperCard {
                        width: parent.width
                        bar: root.bar
                        label: "Thickness"
                        value: Math.round(root.bar.bar.thickness) + "px"
                        onDec: root.bar.applyBar(Object.assign({}, root.bar.bar, { thickness: Math.max(32, root.bar.bar.thickness - 4) }))
                        onInc: root.bar.applyBar(Object.assign({}, root.bar.bar, { thickness: Math.min(96, root.bar.bar.thickness + 4) }))
                    }
                    StepperCard {
                        width: parent.width
                        bar: root.bar
                        label: "Edge margin"
                        value: Math.round(root.bar.bar.edgeGap) + "px"
                        onDec: root.bar.applyBar(Object.assign({}, root.bar.bar, { edgeGap: Math.max(0, root.bar.bar.edgeGap - 2) }))
                        onInc: root.bar.applyBar(Object.assign({}, root.bar.bar, { edgeGap: Math.min(24, root.bar.bar.edgeGap + 2) }))
                    }
                    StepperCard {
                        width: parent.width
                        bar: root.bar
                        label: "Bar opacity"
                        value: Math.round(root.bar.bar.barOpacity * 100) + "%"
                        onDec: root.bar.applyBar(Object.assign({}, root.bar.bar, { barOpacity: Math.max(0.2, +(root.bar.bar.barOpacity - 0.05).toFixed(2)) }))
                        onInc: root.bar.applyBar(Object.assign({}, root.bar.bar, { barOpacity: Math.min(1.0, +(root.bar.bar.barOpacity + 0.05).toFixed(2)) }))
                    }

                    // Toggles (cards de ancho completo)
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰍜"
                        label: "Island fill"
                        checked: root.bar.bar.pillBg
                        onToggled: root.bar.applyBar(Object.assign({}, root.bar.bar, { pillBg: !root.bar.bar.pillBg }))
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰍛"
                        label: "Solid fill"
                        checked: root.bar.bar.pillSolid
                        onToggled: root.bar.applyBar(Object.assign({}, root.bar.bar, { pillSolid: !root.bar.bar.pillSolid }))
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰹑"
                        label: "Unified bar"
                        checked: root.bar.bar.barBg
                        onToggled: root.bar.applyBar(Object.assign({}, root.bar.bar, { barBg: !root.bar.bar.barBg }))
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰚰"
                        label: "Drag modules"
                        checked: root.bar.bar.dragModules !== false
                        onToggled: root.bar.applyBar(Object.assign({}, root.bar.bar, { dragModules: root.bar.bar.dragModules !== false ? false : true }))
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Tip: grab any island and drag it along the bar to reorder it between zones (release outside the bar cancels)."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    // Font (TextField estilo card)
                    FieldCard {
                        width: parent.width
                        bar: root.bar
                        label: "Font"
                        value: root.bar.bar.font || "Hack Nerd Font"
                        fieldWidth: 240
                        previewFont: true
                        onEdited: (text) => {
                            let v = text.trim();
                            root.bar.applyBar(Object.assign({}, root.bar.bar, { font: v !== "" ? v : "Hack Nerd Font" }));
                        }
                    }

                    // Border global: stepper + ColorCycle card
                    Row {
                        width: parent.width
                        spacing: bar.s(10)
                        StepperCard {
                            width: parent.width - bar.s(76)
                            bar: root.bar
                            label: "Border (global)"
                            value: Math.round(root.bar.bar.borderWidth) + "px"
                            onDec: root.bar.applyBar(Object.assign({}, root.bar.bar, { borderWidth: Math.max(0, root.bar.bar.borderWidth - 1) }))
                            onInc: root.bar.applyBar(Object.assign({}, root.bar.bar, { borderWidth: Math.min(8, root.bar.bar.borderWidth + 1) }))
                        }
                        Item {
                            width: bar.s(66)
                            height: bar.s(44)
                            ColorCycle { anchors.centerIn: parent; bar: root.bar; role: root.bar.bar.borderColor; onCycled: (role) => root.bar.applyBar(Object.assign({}, root.bar.bar, { borderColor: role })) }
                        }
                    }

                    // ════ WINDOW BORDERS ════
                    Text {
                        text: "Window borders"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰢮"
                        label: "Follow palette"
                        checked: root.bar.bar.borderFollowPalette !== false
                        onToggled: root.bar.applyBar(Object.assign({}, root.bar.bar, { borderFollowPalette: root.bar.bar.borderFollowPalette !== false ? false : true }))
                    }

                    // Target activo/inactivo (solo sin follow): grid 2 cards
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        visible: bar.bar.borderFollowPalette === false
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "◉"
                            label: "Active"
                            active: root.bar.borderTargetActive
                            onActivated: root.bar.borderTargetActive = true
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "○"
                            label: "Inactive"
                            accentRole: "blue"
                            active: !root.bar.borderTargetActive
                            onActivated: root.bar.borderTargetActive = false
                        }
                    }

                    // Grid de swatches base16 (solo sin follow)
                    GridLayout {
                        width: parent.width
                        columns: 8
                        columnSpacing: bar.s(8)
                        rowSpacing: bar.s(8)
                        visible: bar.bar.borderFollowPalette === false
                        Repeater {
                            model: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool isSel: root.bar.borderTargetActive
                                    ? root.bar.colors.borderHex("active") === root.bar.colors.hexOf(root.bar.colors["color" + modelData])
                                    : root.bar.colors.borderHex("inactive") === root.bar.colors.hexOf(root.bar.colors["color" + modelData])
                                width: bar.s(24)
                                height: bar.s(24)
                                radius: bar.s(8)
                                color: bar.colors["color" + modelData]
                                border.width: isSel ? 2 : 1
                                border.color: isSel ? bar.colors.text : (swMa.containsMouse ? bar.colors.mauve : bar.colors.surface1)
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                MouseArea {
                                    id: swMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let hex = root.bar.colors.hexOf(root.bar.colors["color" + modelData]);
                                        root.bar.applyBar(Object.assign({}, root.bar.bar, root.bar.borderTargetActive
                                            ? { borderActive: hex }
                                            : { borderInactive: hex }));
                                    }
                                }
                            }
                        }
                    }

                    // Preview del color activo/inactivo (solo sin follow)
                    RowLayout {
                        width: parent.width
                        spacing: bar.s(10)
                        visible: bar.bar.borderFollowPalette === false
                        EditLabel {
                            bar: root.bar
                            text: root.bar.borderTargetActive ? "Active color" : "Inactive color"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Rectangle {
                            Layout.preferredWidth: bar.s(92)
                            Layout.preferredHeight: bar.s(30)
                            Layout.alignment: Qt.AlignVCenter
                            radius: bar.s(13)
                            color: root.bar.borderTargetActive ? root.bar.colors.borderHex("active") : root.bar.colors.borderHex("inactive")
                            border.width: 1
                            border.color: root.bar.colors.surface1
                            Text {
                                anchors.centerIn: parent
                                text: root.bar.borderTargetActive ? root.bar.colors.borderHex("active") : root.bar.colors.borderHex("inactive")
                                font.family: "Hack Nerd Font"
                                font.pixelSize: bar.s(11)
                                font.weight: Font.Bold
                                color: root.bar.colors.text
                            }
                        }
                    }

                    // Caption (solo con follow activo)
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        visible: bar.bar.borderFollowPalette !== false
                        text: "Borders follow the active palette accent. Turn this off to pick custom colors (applies live, no window restart)."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
