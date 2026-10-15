import QtQuick
import QtQuick.Layouts
import "../../../core"

// Selector de posición del editor CLASSIC (Fase 4: familia GuidePopup).
// Inactivo: alpha(surface0, 0.4) + borde surface1; hover alpha(mauve, 0.1) +
// borde mauve; activo: relleno mauve + contenido crust; press scale 0.98.
// API intacta: bar / pos / label / glyph / activated().
Rectangle {
    id: card
    property var bar: null
    property string pos: ""
    property string label: ""
    property string glyph: ""
    signal activated()

    readonly property bool isActive: card.bar && card.bar.classic && String(card.bar.classic.position) === card.pos

    height: bar ? bar.s(60) : 60
    radius: bar ? bar.s(Theme.radiusLg) : Theme.radiusLg
    color: !bar ? "transparent"
        : card.isActive
            ? bar.colors.mauve
            : (cardMa.containsMouse ? Theme.stateLayer(bar.colors.mauve, Theme.stateHover) : Theme.surfaceContainerLow)
    border.width: 1
    border.color: !bar ? "transparent"
        : card.isActive
            ? bar.colors.mauve
            : (cardMa.containsMouse ? bar.colors.mauve : Theme.outlineVariant)
    scale: cardMa.pressed ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.centerIn: parent
        spacing: bar ? bar.s(Theme.gapSm) : Theme.gapSm
        Text {
            text: card.glyph
            font.family: "Hack Nerd Font"
            font.pixelSize: bar ? bar.s(22) : 22
            font.weight: Font.Black
            color: !bar ? "transparent" : (card.isActive ? bar.colors.crust : bar.colors.text)
        }
        Text {
            text: card.label
            font.family: "Hack Nerd Font"
            font.pixelSize: bar ? bar.s(13) : 13
            font.weight: Font.Bold
            color: !bar ? "transparent" : (card.isActive ? bar.colors.crust : bar.colors.text)
        }
    }
    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activated()
    }
}
