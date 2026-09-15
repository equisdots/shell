import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"
import "../BarLayout.js" as BarLayout

// ═══════════════════════════════════════════════════════════════════════════
// ModulesPage — BarEditor tab: per-module personalization (icon, color, fill,
// accent) plus the bar-wide icon color. Consumes the module personalization
// API in BarLayout.js through bar.applyBar(...).
//
// Fase 5 (look Guide): título s(24) Black, sub-título s(13), FieldCards para
// los textos y EditorButtons para el fill tri-estado (Default / Filled /
// None). SIN filas con cajita decorativa.
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors,
// bar.bar, bar.applyBar, ...). NEVER touches ids of the editor root. Exposes
// the scroll Flickable via `flickable`.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null

    // Modules whose component calls mod.glyph(): the icon field only has an
    // effect there. Kept in sync with docs/personalization.md.
    readonly property var iconModules: ["help", "search", "settings", "update",
                                        "keyboard", "wifi", "bluetooth", "volume",
                                        "battery", "weather", "focus", "recording"]

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

                    Text {
                        text: "Modules"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    Text {
                        text: "Icons, colors, fill and accent per island. Empty values keep the defaults (a colors.* role name or a #hex)."
                        font.family: "Hack Nerd Font"
                        font.pixelSize: bar.s(13)
                        color: bar.colors.subtext0
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    // ── Bar-wide icon color ───────────────────────────────────
                    FieldCard {
                        width: parent.width
                        bar: root.bar
                        label: "Icon color (global)"
                        value: root.bar.bar.iconColor !== undefined ? root.bar.bar.iconColor : ""
                        fieldWidth: 220
                        onEdited: (text) => root.bar.applyBar(BarLayout.setGlobalIconColor(root.bar.bar, text))
                    }

                    // ── Per module ────────────────────────────────────────────
                    Repeater {
                        model: BarLayout.MODULES

                        delegate: Column {
                            id: modCol
                            width: pageCol.width
                            spacing: bar.s(8)

                            readonly property var cfg: BarLayout.moduleConfig(root.bar.bar, modelData.id)

                            Text {
                                text: modelData.label + "  ·  " + modelData.id
                                font.family: "Hack Nerd Font"
                                font.weight: Font.Bold
                                font.pixelSize: bar.s(16)
                                color: bar.colors.text
                            }

                            GridLayout {
                                width: parent.width
                                columns: 2
                                columnSpacing: bar.s(10)
                                rowSpacing: bar.s(8)

                                FieldCard {
                                    Layout.fillWidth: true
                                    bar: root.bar
                                    label: root.iconModules.indexOf(modelData.id) !== -1 ? "Icon" : "Icon (unused)"
                                    value: modCol.cfg.icon
                                    fieldWidth: 150
                                    maxLength: 4
                                    onEdited: (text) => root.bar.applyBar(BarLayout.setModuleIcon(root.bar.bar, modelData.id, text))
                                }

                                FieldCard {
                                    Layout.fillWidth: true
                                    bar: root.bar
                                    label: "Color"
                                    value: modCol.cfg.color
                                    fieldWidth: 150
                                    onEdited: (text) => root.bar.applyBar(BarLayout.setModuleColor(root.bar.bar, modelData.id, text))
                                }

                                FieldCard {
                                    Layout.fillWidth: true
                                    bar: root.bar
                                    label: "Accent"
                                    value: modCol.cfg.accent
                                    fieldWidth: 150
                                    onEdited: (text) => root.bar.applyBar(BarLayout.setModuleAccent(root.bar.bar, modelData.id, text))
                                }

                                Item { Layout.fillWidth: true; height: 1 }
                            }

                            Row {
                                spacing: bar.s(8)

                                EditorButton {
                                    bar: root.bar
                                    label: "Default fill"
                                    active: modCol.cfg.fill === "default"
                                    onActivated: root.bar.applyBar(BarLayout.setModuleFill(root.bar.bar, modelData.id, "default"))
                                }

                                EditorButton {
                                    bar: root.bar
                                    label: "Filled"
                                    accentRole: "blue"
                                    active: modCol.cfg.fill === "on"
                                    onActivated: root.bar.applyBar(BarLayout.setModuleFill(root.bar.bar, modelData.id, "on"))
                                }

                                EditorButton {
                                    bar: root.bar
                                    label: "None"
                                    accentRole: "red"
                                    active: modCol.cfg.fill === "off"
                                    onActivated: root.bar.applyBar(BarLayout.setModuleFill(root.bar.bar, modelData.id, "off"))
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: bar.colors.surface1
                                opacity: 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
