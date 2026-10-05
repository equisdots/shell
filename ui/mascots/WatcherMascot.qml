import QtQuick

// ─────────────────────────────────────────────────────────────────────────────
// WatcherMascot — the "watcher" species: a living digital clock (HH:MM:SS).
//
// Every field retypes itself with a typewriter wipe: a small cursor runs left
// over the current digits (erasing them), the value swaps, then the cursor
// runs right revealing the new digits. Hours, minutes and seconds all animate
// on every change (the seconds wipe once per second).
//
// Contents are centred and may overflow the design box horizontally, so the
// clock reads well when the mascot is used on its own (count 1).
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: watcher

    property string mood: "idle"
    property real lookX: 0
    property real lookY: 0
    property color tint: "#cba6f7"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color red: "#f38ba8"
    property bool blinking: false
    property real clock: 0
    property var palette: ({})

    readonly property real fs: Math.max(8, Math.round(watcher.height * 0.44))
    readonly property real u: Math.max(1, Math.round(watcher.height * 0.05))
    readonly property color cursorColor: watcher.mood === "angry" ? watcher.red : watcher.tint

    property int secTick: 0
    function pad(n) { return (n < 10 ? "0" : "") + n; }

    Timer {
        interval: 250
        repeat: true
        running: watcher.visible
        onTriggered: watcher.tick()
    }

    function tick() {
        let d = new Date();
        let H = watcher.pad(d.getHours());
        let M = watcher.pad(d.getMinutes());
        let S = watcher.pad(d.getSeconds());
        if (fH.value !== H) fH.setValue(H, true);
        if (fM.value !== M) fM.setValue(M, true);
        if (fS.value !== S) fS.setValue(S, true);
        watcher.secTick = d.getSeconds();
    }

    // ── one typewriter field ────────────────────────────────────────────────
    component WField: Item {
        id: wf
        property string value: "00"
        property string shown: "00"
        property real fs: 10
        property real u: 1
        property color textColor: "#cdd6f4"
        property color cursorColor: "#cba6f7"
        property real rev: 1

        readonly property real fullW: wfText.implicitWidth
        implicitWidth: fullW
        implicitHeight: wfText.implicitHeight

        function setValue(v, animate) {
            wf.value = v;
            if (!animate || wf.shown === v) {
                wf.shown = v;
                wf.rev = 1;
                anim.stop();
                return;
            }
            anim.restart();
        }

        Item {
            id: clip
            width: wf.fullW * wf.rev
            height: wf.height
            clip: true
            Text {
                id: wfText
                text: wf.shown
                font.family: "Hack Nerd Font"
                font.weight: Font.Black
                font.pixelSize: wf.fs
                color: wf.textColor
            }
        }
        Rectangle {
            x: clip.width - wf.u
            width: wf.u
            height: wf.height
            color: wf.cursorColor
            visible: wf.rev > 0.001 && wf.rev < 0.999
        }

        SequentialAnimation {
            id: anim
            NumberAnimation { target: wf; property: "rev"; to: 0; duration: 150; easing.type: Easing.InCubic }
            PropertyAction { target: wf; property: "shown"; value: wf.value }
            NumberAnimation { target: wf; property: "rev"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: watcher.u

        WField {
            id: fH
            fs: watcher.fs
            u: watcher.u
            textColor: watcher.text
            cursorColor: watcher.cursorColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            font.family: "Hack Nerd Font"
            font.weight: Font.Black
            font.pixelSize: watcher.fs
            color: watcher.text
            opacity: (watcher.secTick % 2 === 0) ? 1.0 : 0.3
        }
        WField {
            id: fM
            fs: watcher.fs
            u: watcher.u
            textColor: watcher.text
            cursorColor: watcher.cursorColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            font.family: "Hack Nerd Font"
            font.weight: Font.Black
            font.pixelSize: watcher.fs
            color: watcher.text
            opacity: (watcher.secTick % 2 === 0) ? 1.0 : 0.3
        }
        WField {
            id: fS
            fs: watcher.fs
            u: watcher.u
            textColor: watcher.text
            cursorColor: watcher.cursorColor
        }
    }
}
