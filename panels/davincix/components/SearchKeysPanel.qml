// ═══════════════════════════════════════════════════════════════════════════
// davincix · ui/components — SearchKeysPanel
//
// Panel de API keys de proveedores (las que pidan). Los datos vienen del
// kernel (`davincix.sh keys list`: NAME|label|where|0-1); guardar delega en
// `keys set`. Overlay flotante; click fuera o ESC cierran.
// ═══════════════════════════════════════════════════════════════════════════
import QtQuick

Item {
    id: panelRoot

    required property var ctx        // picker root (s(), estado)
    required property var theme      // Colors instance

    property bool open: false
    property var keys: []            // [{name,label,where,set}]
    property real topOffset: 0       // y del panel (bajo la barra de filtros)

    signal saveRequested(string name, string value)
    signal closed()

    visible: open
    z: 45
    anchors.fill: parent

    // Click fuera → cerrar (dim suave, panel flotante de la barra).
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
        anchors.top: parent.top
        anchors.topMargin: panelRoot.topOffset
        anchors.right: parent.right
        anchors.rightMargin: ctx.s(30)
        width: ctx.s(350)
        height: content.implicitHeight + ctx.s(28)
        radius: ctx.s(16)
        color: Qt.rgba(theme.mantle.r, theme.mantle.g, theme.mantle.b, 0.96)
        border.color: theme.surface2
        border.width: 1

        // Los clicks dentro de la card no cierran el panel.
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: ctx.s(14)
            spacing: ctx.s(10)

            Text {
                text: "Provider API keys"
                color: theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(14)
                font.bold: true
            }

            Text {
                text: "Only for sources that need one. Saved locally."
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.6)
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(10)
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: panelRoot.keys

                delegate: Column {
                    width: content.width
                    spacing: ctx.s(4)

                    Row {
                        width: parent.width
                        spacing: ctx.s(8)

                        Text {
                            id: keyLabel
                            text: modelData.label
                            color: theme.text
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(13)
                            font.bold: true
                        }

                        Item {
                            width: Math.max(0, parent.width - keyLabel.implicitWidth - keyStatus.implicitWidth - ctx.s(16))
                            height: 1
                        }

                        Text {
                            id: keyStatus
                            text: modelData.set ? "set" : "not set"
                            color: modelData.set
                                ? theme.green
                                : Qt.rgba(theme.yellow.r, theme.yellow.g, theme.yellow.b, 0.85)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: ctx.s(11)
                            font.bold: true
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: ctx.s(6)

                        Rectangle {
                            id: inputBox
                            width: parent.width - saveBtn.width - ctx.s(6)
                            height: ctx.s(32)
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
                                font.pixelSize: ctx.s(12)
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
                                font.pixelSize: ctx.s(12)
                            }
                        }

                        Rectangle {
                            id: saveBtn
                            width: saveText.implicitWidth + ctx.s(20)
                            height: ctx.s(32)
                            radius: ctx.s(10)
                            property bool ready: keyInput.text.trim() !== ""

                            color: ready
                                ? (saveMouse.containsMouse ? Qt.alpha(theme.mauve, 0.9) : Qt.alpha(theme.mauve, 0.75))
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

                    Text {
                        text: "free at " + modelData.where
                        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.5)
                        font.family: "Hack Nerd Font"
                        font.pixelSize: ctx.s(10)
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
