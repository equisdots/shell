// ═══════════════════════════════════════════════════════════════════════════
// davincix · ui/components — SearchKeysPanel
//
// Panel de API keys de proveedores (las que pidan). Los datos vienen del
// kernel (`davincix.sh keys list`: NAME|label|where|0-1); guardar delega en
// `keys set`.
//
// Estilo: réplica del panel principal (DavincixFilterBar) — contenedor
// mantle 0.90 + borde surface2 + radio s(18), y dentro pills surface0/
// surface1 con radio s(13), bordes y tipografías del mismo lenguaje.
// Se renderiza centrado bajo la tira de wallpapers, ancho de la búsqueda.
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick
import "../../../../core"

Item {
    id: panelRoot

    required property var ctx        // picker root (s(), estado)
    required property var theme      // Colors instance (paleta activa)

    property bool open: false
    property var keys: []            // [{name,label,where,set}]

    signal saveRequested(string name, string value)
    signal closed()

    visible: open
    z: 45
    anchors.fill: parent

    // Click fuera → cerrar (dim suave, como el ConfirmDialog).
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.25)

        MouseArea {
            anchors.fill: parent
            onClicked: panelRoot.closed()
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.gapMd
        width: ctx.s(440)
        height: rows.implicitHeight + ctx.s(20)
        radius: Theme.radiusLg

        color: Theme.surfaceContainerHigh
        border.color: Theme.outlineVariant
        border.width: 1

        // Los clicks dentro de la card no cierran el panel.
        MouseArea { anchors.fill: parent }

        Column {
            id: rows
            anchors.fill: parent
            anchors.margins: Theme.gapSm
            spacing: Theme.gapSm

            Repeater {
                model: panelRoot.keys

                delegate: Row {
                    width: rows.width
                    spacing: Theme.gapSm

                    // Pill del proveedor: mismo estilo que el botón de
                    // transición de la barra (surface0, borde surface1).
                    Rectangle {
                        id: provPill
                        width: provRow.width + ctx.s(20)
                        height: ctx.s(36)
                        radius: Theme.radiusMd

                        color: Theme.surfaceContainer
                        border.color: Theme.outlineVariant
                        border.width: 1

                        Row {
                            id: provRow
                            anchors.centerIn: parent
                            spacing: Theme.gapXs

                            Rectangle {
                                width: ctx.s(8)
                                height: ctx.s(8)
                                radius: Theme.radiusXs
                                color: modelData.set ? theme.green : theme.yellow
                            }

                            Text {
                                text: modelData.label
                                color: theme.text
                                font.family: "Hack Nerd Font"
                                font.pixelSize: ctx.s(11)
                            }

                            Text {
                                text: modelData.set ? "set" : "not set"
                                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.55)
                                font.family: "Hack Nerd Font"
                                font.pixelSize: ctx.s(10)
                            }
                        }
                    }

                    // Input: mismo estilo que la caja de búsqueda (surface2
                    // al 0.8, borde theme.text al enfocar).
                    Rectangle {
                        id: inputBox
                        width: rows.width - provPill.width - savePill.width - ctx.s(16)
                        height: ctx.s(36)
                        radius: Theme.radiusMd

                        color: Theme.surfaceContainer
                        border.color: keyInput.activeFocus ? theme.text : Theme.outlineVariant
                        border.width: keyInput.activeFocus ? ctx.s(2) : 1

                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        TextInput {
                            id: keyInput
                            anchors.fill: parent
                            anchors.leftMargin: Theme.gapMd
                            anchors.rightMargin: Theme.gapMd
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.text
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(11)
                            clip: true
                            selectionColor: Qt.alpha(theme.mauve, 0.5)
                            selectedTextColor: theme.text

                            onAccepted: panelRoot.saveRequested(modelData.name, keyInput.text)
                        }

                        // Placeholder manual (TextInput no lo soporta aquí).
                        Text {
                            visible: keyInput.text === ""
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.gapMd
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.gapMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.set
                                ? "replace " + modelData.name + "..."
                                : "paste " + modelData.name + " · free at " + modelData.where
                            color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.35)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(11)
                            elide: Text.ElideRight
                        }
                    }

                    // Guardar: mismo estilo que el botón submit de la caja de
                    // búsqueda (borde surface2 → theme.text, hover surface1).
                    Rectangle {
                        id: savePill
                        width: saveRow.width + ctx.s(22)
                        height: ctx.s(36)
                        radius: Theme.radiusMd
                        property bool ready: keyInput.text.trim() !== ""

                        color: (saveMouse.containsMouse && ready) ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                        border.color: ready && saveMouse.containsMouse ? theme.text : Theme.outlineVariant
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            id: saveRow
                            anchors.centerIn: parent
                            spacing: Theme.gapXs

                            Text {
                                text: "\uF00C"  // fa-check
                                color: savePill.ready
                                    ? theme.text
                                    : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.35)
                                font.family: "Hack Nerd Font"
                                font.pixelSize: ctx.s(11)
                            }

                            Text {
                                text: "Save"
                                color: savePill.ready
                                    ? theme.text
                                    : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.35)
                                font.family: "Hack Nerd Font"
                                font.pixelSize: ctx.s(11)
                            }
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: savePill.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panelRoot.saveRequested(modelData.name, keyInput.text)
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: panelRoot.open
        onActivated: panelRoot.closed()
    }
}
