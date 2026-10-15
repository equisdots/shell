import QtQuick
import Quickshell
import "../../../core"
import ".."

// Recording indicator — red accent island + blinking icon while recording.
ModulePill {
    id: mod
    moduleId: "recording"

    padH: bar.s(6)
    accentRole: "red"
    accentActive: bar.isRecording
    pulse: true
    showState: bar.isRecording

    // The screenshots plugin owns the script; resolve its deployed copy
    // (managed registry + UI tree, user plugin) with the transitional core
    // path as the last resort.
    readonly property string screenshotCmd: "S=; for c in \"$HOME/.config/hypr/plugins/screenshots/scripts/screenshot.sh\" \"$HOME/.config/hypr/scripts/quickshell/ui/plugins/screenshots/scripts/screenshot.sh\" \"$HOME/.config/hypr/plugins-user/screenshots/scripts/screenshot.sh\" \"$HOME/.config/hypr/scripts/screenshot.sh\"; do [ -f \"$c\" ] && { S=\"$c\"; break; }; done; [ -n \"$S\" ] && exec bash \"$S\""

    onClicked: {
        bar.isRecording = false;
        Quickshell.execDetached(["bash", "-c", screenshotCmd]);
    }

    Text {
        text: mod.glyph("")
        font.family: bar.fontFamily
        font.pixelSize: bar.s(20)
        color: mod.contentColor

        SequentialAnimation on opacity {
            running: bar.isRecording && !mod.hovered
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }
    }
}
