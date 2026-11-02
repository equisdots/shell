import QtQuick
import "."

// ============================================================================
// GlassCard — translucent surface for desktop-widget faces.
//
// Lives in core/ so faces reach it through their existing `import "../../../core"`
// (the implicit sibling-directory import does not resolve under Quickshell's
// component loader). Colors are passed in by the caller (Theme.widgetFill /
// Theme.widgetHairline). Renders the base fill, a 1px hairline border and a
// subtle top-down sheen; when global liquid glass is on and the widget sits
// near the screen center, a LiquidGlass lens replaces the fill.
// ============================================================================

Rectangle {
    id: card

    property color fill: "transparent"
    property color hairline: "transparent"
    property real cornerRadius: 10

    radius: cornerRadius
    antialiasing: true
    // When the lens is active the card fill steps aside; otherwise the face
    // keeps its normal fill (solid, translucent or transparent for artwork).
    color: glass.visible ? "transparent" : fill
    border.width: 1
    border.color: hairline

    LiquidGlass {
        id: glass
        anchors.fill: parent
        enabled: Theme.liquidGlass
        centeredOnly: true
        topLeftRadius: card.cornerRadius
        topRightRadius: card.cornerRadius
        bottomLeftRadius: card.cornerRadius
        bottomRightRadius: card.cornerRadius
        tintColor: "#101018"
        tintAmount: 0.30
        bezel: Math.max(6, Math.min(16, Math.min(width, height) * 0.24))
        frost: Math.max(4, Math.min(12, Math.min(width, height) * 0.18))
        interiorShade: 0.24
        rim: 0.88
    }

    // Frosted sheen: soft light at the top, faint shadow at the bottom.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, card.cornerRadius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.32; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.07) }
        }
    }
}
