import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Clock — text island, blue accent. Compact (vertical): HH:mm.
// Personalization: format (bar.timeFormat), size/color/accent/fill and the
// optional typewriter effect with a blinking cursor (module config).
ModulePill {
    id: mod
    moduleId: "time"

    fullHeight: true
    idleRole: "blue"
    padH: bar.s(18)

    readonly property bool tw: mod.moduleCfg.effect === "typewriter"
    readonly property bool cursorOn: mod.moduleCfg.cursor !== false
    readonly property int clockSize: mod.moduleCfg.size > 0
        ? bar.s(mod.moduleCfg.size)
        : bar.s(mod.horizontal ? 16 : 14)

    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])

    Text {
        visible: mod.horizontal && !mod.tw
        text: bar.timeStr
        font.family: bar.fontFamily
        font.pixelSize: mod.clockSize
        font.weight: Font.Black
        color: mod.contentColor
    }

    // Typewriter: one Text per character slot; only the characters that change
    // replay the reveal (seconds every second, minutes and hours on their own
    // change), plus a blinking cursor at the end.
    RowLayout {
        visible: mod.horizontal && mod.tw
        spacing: 0

        Repeater {
            model: 12

            delegate: Text {
                id: twChar
                required property int index
                readonly property string ch: bar.timeStr.length > index ? bar.timeStr.charAt(index) : ""
                Layout.alignment: Qt.AlignVCenter
                text: ch
                font.family: bar.fontFamily
                font.pixelSize: mod.clockSize
                font.weight: Font.Black
                color: mod.contentColor

                SequentialAnimation {
                    id: revealAnim
                    PauseAnimation { duration: twChar.index * 12 }
                    NumberAnimation { target: twChar; property: "opacity"; from: 0; to: 1; duration: 100; easing.type: Easing.OutQuad }
                }
                onChChanged: revealAnim.restart()
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: mod.cursorOn ? bar.s(4) : 0
            Layout.preferredHeight: mod.clockSize + bar.s(2)

            Rectangle {
                anchors.centerIn: parent
                width: bar.s(2)
                height: parent.height - bar.s(2)
                color: mod.contentColor
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.1; duration: 480 }
                    NumberAnimation { to: 1.0; duration: 480 }
                }
            }
        }
    }

    // Compact: just HH:mm, clamped to the pill so it never overflows.
    Text {
        visible: mod.compact
        width: Math.max(bar.s(28), bar.pillWidth - bar.s(8))
        text: bar.timeStr.length >= 5 ? bar.timeStr.substring(0, 5) : bar.timeStr
        font.family: bar.fontFamily
        font.pixelSize: mod.clockSize
        font.weight: Font.Black
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: mod.contentColor
    }
}
