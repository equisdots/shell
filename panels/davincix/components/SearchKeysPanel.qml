// ═══════════════════════════════════════════════════════════════════════════
// davincix · ui/components — SearchKeysPanel
//
// Panel de API keys de proveedores (las que pidan). Los datos vienen del
// kernel (`davincix.sh keys list`: NAME|label|where|0-1); guardar delega en
// `keys set`. Se renderiza centrado bajo la tira de wallpapers, con el ancho
// de la barra de búsqueda, y todos los colores salen de la paleta (theme).
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick

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

    // Click fuera → cerrar (dim suave).
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.25)

        MouseArea {
            anchors.fill: parent
            onClicked: panelRoot.closed()
        }
    }

    // Card: mismo ancho que la barra de búsqueda, centrada, anclada abajo
    // (queda justo bajo la tira de wallpapers).
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ctx.s(14)
        width: ctx.s(440)
        height: content.implicitHeight + ctx.s(24)
        radius: ctx.s(18)

        color: Qt.rgba(theme.mantle.r, theme.mantle.g, theme.mantle.b, 0.94)
        border.color: theme.surface2
        border.width: 1

        // Los clicks dentro de la card no cierran el panel.
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: ctx.s(12)
            spacing: ctx.s(8)

            Row {
                width: parent.width
                spacing: ctx.s(8)

                Text {
                    id: panelTitle
                    text: "Provider API keys"
                    color: theme.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: ctx.s(13)
                    font.bold: true
                }

                Item {
                    width: Math.max(0, parent.width - panelTitle.implicitWidth - hintText.implicitWidth - ctx.s(24))
                    height: 1
                }

                Text {
                    id: hintText
                    text: "free · saved locally"
                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.45)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: ctx.s(9)
                }
            }

            Repeater {
                model: panelRoot.keys

                delegate: Row {
                    width: content.width
                    spacing: ctx.s(10)

                    // Label + estado + dónde conseguirla.
                    Item {
                        width: ctx.s(148)
                        height: ctx.s(34)

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: ctx.s(1)

                            Row {
                                spacing: ctx.s(6)

                                Text {
                                    text: modelData.label
                                    color: theme.text
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: ctx.s(12)
                                    font.bold: true
                                }

                                Text {
                                    text: modelData.set ? "set" : "not set"
                                    color: modelData.set
                                        ? theme.green
                                        : Qt.rgba(theme.yellow.r, theme.yellow.g, theme.yellow.b, 0.85)
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: ctx.s(10)
                                    font.bold: true
                                }
                            }

                            Text {
                                text: modelData.where
                                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.45)
                                font.family: "Hack Nerd Font"
                                font.pixelSize: ctx.s(9)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Input de la key.
                    Rectangle {
                        id: inputBox
                        width: parent.width - ctx.s(148) - saveBtn.width - ctx.s(20)
                        height: ctx.s(34)
                        radius: ctx.s(10)

                        color: Qt.alpha(theme.surface0, 0.7)
                        border.color: keyInput.activeFocus ? theme.mauve : theme.surface1
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: keyInput
                            anchors.fill: parent
                            anchors.leftMargin: ctx.s(10)
                            anchors.rightMargin: ctx.s(10)
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
                            anchors.leftMargin: ctx.s(10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.set ? "replace key..." : "paste " + modelData.name + "..."
                            color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.35)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(11)
                        }
                    }

                    // Guardar (acento mauve de la paleta, contenido crust).
                    Rectangle {
                        id: saveBtn
                        width: saveText.implicitWidth + ctx.s(20)
                        height: ctx.s(34)
                        radius: ctx.s(10)
                        property bool ready: keyInput.text.trim() !== ""

                        color: ready
                            ? (saveMouse.containsMouse
                                ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.92)
                                : Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.78))
                            : Qt.alpha(theme.surface0, 0.5)
                        border.color: ready ? theme.mauve : theme.surface1
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: saveText
                            anchors.centerIn: parent
                            text: "Save"
                            color: saveBtn.ready
                                ? theme.crust
                                : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.4)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(11)
                            font.bold: true
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: saveBtn.ready
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
