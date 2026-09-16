import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"

// ═══════════════════════════════════════════════════════════════════════════
// PositionPage — BarEditor tab: bar position selector.
//
// Fase 5 (look Guide): título s(24) Black + grid 2 columnas de cards
// (PosCard/PosCardClassic ya en estilo card-guide: alto s(60), radio s(18),
// activo mauve/crust). Sin filas ni cajitas decorativas.
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors,
// bar.bar / bar.classic, bar.applyBar / bar.applyClassic, ...). NEVER touches ids
// of the editor root. Exposes the scroll Flickable via `flickable`.
//
// PosCard writes straight through bar.applyBar; PosCardClassic emits
// activated() and this page routes it through bar.applyClassic.
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

                    // Título de página (GP:1007-1014)
                    Text {
                        text: "Position"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    // ── Bar engine: PosCard 2×2 (escribe vía applyBar) ──
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        visible: bar.engine === "bar"
                        PosCard { Layout.fillWidth: true; bar: root.bar; barRef: root.bar.bar; pos: "top"; label: "Top"; glyph: "↑" }
                        PosCard { Layout.fillWidth: true; bar: root.bar; barRef: root.bar.bar; pos: "bottom"; label: "Bottom"; glyph: "↓" }
                        PosCard { Layout.fillWidth: true; bar: root.bar; barRef: root.bar.bar; pos: "left"; label: "Left"; glyph: "←" }
                        PosCard { Layout.fillWidth: true; bar: root.bar; barRef: root.bar.bar; pos: "right"; label: "Right"; glyph: "→" }
                    }

                    // ── Classic engine: PosCardClassic 2×2 (rutea a applyClassic) ──
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        visible: bar.engine === "classic"
                        PosCardClassic { Layout.fillWidth: true; bar: root.bar; pos: "top"; label: "Top"; glyph: "↑"; onActivated: root.bar.applyClassic({ position: "top" }) }
                        PosCardClassic { Layout.fillWidth: true; bar: root.bar; pos: "bottom"; label: "Bottom"; glyph: "↓"; onActivated: root.bar.applyClassic({ position: "bottom" }) }
                        PosCardClassic { Layout.fillWidth: true; bar: root.bar; pos: "left"; label: "Left"; glyph: "←"; onActivated: root.bar.applyClassic({ position: "left" }) }
                        PosCardClassic { Layout.fillWidth: true; bar: root.bar; pos: "right"; label: "Right"; glyph: "→"; onActivated: root.bar.applyClassic({ position: "right" }) }
                    }

                    // Preview: pantalla simulada, la barra se mueve al borde activo
                    Rectangle {
                        id: posPreview
                        width: parent.width
                        radius: bar.s(16)
                        color: Qt.alpha(bar.colors.surface0, 0.4)
                        border.width: 1
                        border.color: bar.colors.surface1
                        height: bar.s(240)
                        readonly property string activePos: bar.engine === "classic"
                            ? (bar.classic.position || "top") : (bar.bar.position || "top")
                        Rectangle {
                            id: screenMock
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.62)
                            height: parent.height - bar.s(28)
                            radius: bar.s(10)
                            color: Qt.alpha(bar.colors.surface1, 0.35)
                            border.width: 1
                            border.color: Qt.alpha(bar.colors.surface1, 0.9)
                            Rectangle {
                                id: barMock
                                readonly property bool vertical: posPreview.activePos === "left" || posPreview.activePos === "right"
                                // Grosor real del engine activo, escalado a la miniatura
                                readonly property real mockThick: {
                                    let t = (bar.engine === "classic")
                                        ? (bar.classic.thickness || 36)
                                        : (bar.bar.thickness || 36);
                                    return Math.max(bar.s(6), Math.min(bar.s(20), Math.round(bar.s(t) * 0.28)));
                                }
                                x: posPreview.activePos === "right" ? parent.width - width : 0
                                y: posPreview.activePos === "bottom" ? parent.height - height : 0
                                width: vertical ? mockThick : parent.width
                                height: vertical ? parent.height : mockThick
                                radius: bar.s(4)
                                color: Qt.alpha(bar.colors.mauve, 0.85)
                                border.width: 1
                                border.color: bar.colors.mauve
                                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: bar.s(6)
                            text: "position: " + posPreview.activePos
                            font.family: "Hack Nerd Font"
                            font.pixelSize: bar.s(11)
                            color: bar.colors.subtext0
                        }
                    }
                }
            }
        }
    }
}
