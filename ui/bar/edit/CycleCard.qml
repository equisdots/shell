import QtQuick
import QtQuick.Layouts
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// CycleCard — dense left/right cycle control (familia GuidePopup).
//
// Used for the 0.57 blur variant (11 names): the label + cost hint sit on the
// left, the current name in the middle and two small chevrons on the right.
// The chevron hitboxes are separate 26 px buttons; the rest of the row is not
// clickable, so nothing overlaps.
//
// API: bar / icon / label / model (display strings) / index / hint / hintColor /
//      accentColor + signal stepped(delta), delta is -1 or +1.
// ═══════════════════════════════════════════════════════════════════════════

Rectangle {
    id: cyc
    property var bar: null
    property string icon: ""
    property string label: ""
    property var model: []
    property int index: 0
    property string hint: ""
    property color hintColor: "#fab387"
    property color accentColor: "#74c7ec"
    signal stepped(int delta)

    readonly property int count: model ? model.length : 0
    readonly property string current: count > 0
        ? String(model[Math.max(0, Math.min(count - 1, index))])
        : ""

    height: bar ? bar.s(48) : 48
    radius: bar ? bar.s(Theme.radiusLg) : Theme.radiusLg
    color: bar ? Theme.surfaceContainerLow : "transparent"
    border.width: 1
    border.color: bar ? Theme.outlineVariant : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: bar ? bar.s(Theme.gapLg) : Theme.gapLg
        anchors.rightMargin: bar ? bar.s(Theme.gapSm) : Theme.gapSm
        spacing: bar ? bar.s(Theme.gapSm) : Theme.gapSm

        Text {
            text: cyc.icon
            font.family: "Hack Nerd Font"
            font.pixelSize: bar ? bar.s(14) : 14
            color: cyc.accentColor
            Layout.preferredWidth: bar ? bar.s(20) : 20
            Layout.alignment: Qt.AlignVCenter
        }

        // Label + short cost hint (e.g. "Animated, high cost").
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Text {
                text: cyc.label
                font.family: "Hack Nerd Font"
                font.pixelSize: bar ? bar.s(11) : 11
                color: bar ? bar.colors.subtext0 : "transparent"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: cyc.hint !== ""
                text: cyc.hint
                font.family: "Hack Nerd Font"
                font.pixelSize: bar ? bar.s(9) : 9
                color: cyc.hintColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Previous.
        Rectangle {
            Layout.preferredWidth: bar ? bar.s(26) : 26
            Layout.preferredHeight: bar ? bar.s(26) : 26
            Layout.alignment: Qt.AlignVCenter
            radius: bar ? bar.s(Theme.radiusSm) : Theme.radiusSm
            color: !bar ? "transparent"
                : (prevMa.containsMouse ? Theme.stateLayer(cyc.accentColor, Theme.stateHover)
                                        : Theme.surfaceContainer)
            border.width: 1
            border.color: !bar ? "transparent"
                : (prevMa.containsMouse ? cyc.accentColor : Theme.outlineVariant)
            Text {
                anchors.centerIn: parent
                text: "\uF104"
                font.family: "Hack Nerd Font"
                font.pixelSize: bar ? bar.s(12) : 12
                color: bar ? bar.colors.text : "transparent"
            }
            MouseArea {
                id: prevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cyc.stepped(-1)
            }
        }

        // Current variant name.
        Text {
            text: cyc.current
            font.family: "Hack Nerd Font"
            font.weight: Font.Bold
            font.pixelSize: bar ? bar.s(12) : 12
            color: bar ? bar.colors.text : "transparent"
            Layout.preferredWidth: bar ? bar.s(104) : 104
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }

        // Next.
        Rectangle {
            Layout.preferredWidth: bar ? bar.s(26) : 26
            Layout.preferredHeight: bar ? bar.s(26) : 26
            Layout.alignment: Qt.AlignVCenter
            radius: bar ? bar.s(Theme.radiusSm) : Theme.radiusSm
            color: !bar ? "transparent"
                : (nextMa.containsMouse ? Theme.stateLayer(cyc.accentColor, Theme.stateHover)
                                        : Theme.surfaceContainer)
            border.width: 1
            border.color: !bar ? "transparent"
                : (nextMa.containsMouse ? cyc.accentColor : Theme.outlineVariant)
            Text {
                anchors.centerIn: parent
                text: "\uF105"
                font.family: "Hack Nerd Font"
                font.pixelSize: bar ? bar.s(12) : 12
                color: bar ? bar.colors.text : "transparent"
            }
            MouseArea {
                id: nextMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cyc.stepped(1)
            }
        }
    }
}
