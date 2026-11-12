import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../../../core"
import "../.."

// ═══════════════════════════════════════════════════════════════════════════
// MusicPopup — Roundhouse.
//
// A vinyl-first redesign of the SUPER+M music popup:
//   · the album art is the label of a spinning record;
//   · the tonearm is the play/pause state;
//   · the outer ring is the track progress;
//   · the lower band is the existing 10-band EasyEffects equalizer.
//
// Everything is palette-driven through Colors: the record, the ink, the
// accent and the EQ footer follow the active equisdots palette live.
// Data and actions keep the old contract:
//   music_info.sh · equalizer.sh · player_control.sh
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    clip: true

    // --- scale + palette -----------------------------------------------------
    Scaler {
        id: scaler
        currentWidth: Screen.width
        currentHeight: Screen.height
    }

    Colors { id: _theme }

    function s(val) { return scaler.s(val); }

    readonly property color accent: _theme.accent
    readonly property color accent2: _theme.yellow
    readonly property color ink: _theme.text
    readonly property color muted: _theme.overlay0
    readonly property color base: _theme.base
    readonly property color surface: _theme.surface0
    readonly property color surfaceHi: _theme.surface1
    readonly property color hairline: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)

    readonly property string mono: "Hack Nerd Font"

    // --- state ---------------------------------------------------------------
    property var musicData: ({
        "title": "Loading...", "artist": "", "status": "Stopped", "percent": 0,
        "lengthStr": "00:00", "positionStr": "00:00", "timeStr": "--:-- / --:--",
        "source": "Offline", "playerName": "", "blur": "", "grad": "",
        "textColor": "", "deviceIcon": "", "deviceName": "Speaker",
        "artUrl": "", "length": 0, "position": 0
    })

    property var eqData: ({
        "b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0,
        "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0,
        "preset": "Flat", "pending": false
    })

    property bool userToggledPlay: false
    property real lastEqUpdate: 0
    property bool seeking: false
    property real seekPct: 0

    readonly property bool playing: root.musicData && root.musicData.status === "Playing"
    readonly property real displayPct: root.seeking ? root.seekPct
        : Math.max(0, Math.min(100, Number(root.musicData.percent) || 0))
    readonly property string statusLabel: {
        let st = root.musicData && root.musicData.status ? String(root.musicData.status) : "Stopped";
        return st.toUpperCase();
    }
    readonly property string coverSource: {
        if (!root.musicData || !root.musicData.artUrl) return "";
        const url = String(root.musicData.artUrl);
        return url.indexOf("placeholder_blank") === -1 ? "file://" + url : "";
    }

    // --- helpers -------------------------------------------------------------
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    function safePlayer() {
        return String((root.musicData && root.musicData.playerName) || "")
            .replace(/["\\$`]/g, "");
    }

    function execCmd(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function control(cmd) {
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/player_control.sh "
            + cmd + " \"\" \"\" \"" + root.safePlayer() + "\"");
    }

    function togglePlay() {
        let next = root.playing ? "Paused" : "Playing";
        let d = Object.assign({}, root.musicData);
        d.status = next;
        root.musicData = d;
        root.userToggledPlay = true;
        playDebounce.restart();
        root.control("play-pause");
    }

    function seekTo(fraction) {
        let pct = Math.max(0, Math.min(100, fraction * 100));
        let len = Number(root.musicData.length) || 0;
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/player_control.sh seek "
            + pct.toFixed(2) + " " + len + " \"" + root.safePlayer() + "\"");
        root.seekPct = pct;
        root.seeking = true;
        seekReset.restart();
    }

    function pctFromX(x, w) {
        return w > 0 ? Math.max(0, Math.min(100, (x / w) * 100)) : 0;
    }

    function setBandValue(index, norm) {
        let db = Math.round(root.clamp01(norm) * 24 - 12);
        let d = Object.assign({}, root.eqData);
        d["b" + (index + 1)] = db;
        d.preset = "Custom";
        d.pending = true;
        root.eqData = d;
        root.lastEqUpdate = Date.now();
    }

    function commitBand(index) {
        let value = Number(root.eqData["b" + (index + 1)]) || 0;
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/equalizer.sh set_band "
            + (index + 1) + " " + value);
    }

    function applyPreset(name) {
        let presets = {
            "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Bass":    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
            "Vocal":   [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
            "Rock":    [5, 4, 2, -1, -2, -1, 2, 4, 5, 6]
        };
        if (!presets[name]) return;
        let d = Object.assign({}, root.eqData);
        for (let i = 0; i < 10; i++) d["b" + (i + 1)] = presets[name][i];
        d.preset = name;
        d.pending = false;
        root.eqData = d;
        root.lastEqUpdate = Date.now();
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/equalizer.sh preset " + name);
    }

    function applyEq() {
        root.execCmd("$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/equalizer.sh apply");
        let d = Object.assign({}, root.eqData);
        d.pending = false;
        root.eqData = d;
        root.lastEqUpdate = Date.now();
    }

    // --- polling -------------------------------------------------------------
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!musicProc.running) musicProc.running = true;
            if (!eqProc.running) eqProc.running = true;
        }
    }

    Timer {
        id: playDebounce
        interval: 1500
        onTriggered: root.userToggledPlay = false
    }

    Timer {
        id: seekReset
        interval: 1200
        onTriggered: root.seeking = false
    }

    Process {
        id: musicProc
        running: false
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                let outStr = this.text.trim();
                if (!outStr) return;
                try {
                    let d = JSON.parse(outStr);
                    if (root.userToggledPlay) d.status = root.musicData.status;
                    root.musicData = d;
                } catch (e) {}
            }
        }
    }

    Process {
        id: eqProc
        running: false
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/ui/bar/popups/music/equalizer.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - root.lastEqUpdate < 2000) return;
                if (!this.text) return;
                try { root.eqData = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    // --- panel ---------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: root.s(20)
        color: root.base
        border.width: root.s(1)
        border.color: root.hairline
    }

    Rectangle {
        id: glow
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.s(520)
        height: width
        radius: width / 2
        color: root.accent
        opacity: 0.07
        x: -root.s(190)
        y: -root.s(230)
    }

    // ── header ───────────────────────────────────────────────────────────────
    Item {
        id: topRow
        anchors.top: panel.top
        anchors.left: panel.left
        anchors.right: panel.right
        anchors.margins: root.s(26)
        height: root.s(30)

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.s(8)
            Text {
                text: "EQUISDOTS"
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.s(9)
                font.bold: true
                font.letterSpacing: root.s(2)
            }
            Text {
                text: "/"
                color: root.accent
                font.family: root.mono
                font.pixelSize: root.s(9)
            }
            Text {
                text: "SIDE A"
                color: root.muted
                font.family: root.mono
                font.pixelSize: root.s(9)
                font.letterSpacing: root.s(2)
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.s(8)
            Rectangle {
                width: root.s(6)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.playing ? root.accent : root.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusLabel
                color: root.playing ? root.accent : root.muted
                font.family: root.mono
                font.pixelSize: root.s(9)
                font.letterSpacing: root.s(2)
            }
        }
    }

    // ── main: record + metadata ──────────────────────────────────────────────
    Item {
        id: mainArea
        anchors.top: topRow.bottom
        anchors.left: panel.left
        anchors.right: panel.right
        anchors.bottom: eqPanel.top
        anchors.leftMargin: root.s(26)
        anchors.rightMargin: root.s(26)
        anchors.topMargin: root.s(8)
        anchors.bottomMargin: root.s(12)

        Item {
            id: discWrap
            width: root.s(330)
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            // Outer progress ring.
            Canvas {
                id: ringCanvas
                anchors.fill: parent
                property real pct: root.displayPct
                onPctChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()

                Connections {
                    target: _theme
                    function onPaletteApplied() { ringCanvas.requestPaint(); }
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let cx = width / 2;
                    let cy = height / 2;
                    let r = Math.min(cx, cy) - root.s(2);
                    let lw = Math.max(1, root.s(2));
                    ctx.lineWidth = lw;

                    ctx.globalAlpha = 0.22;
                    ctx.strokeStyle = _theme.hexOf(root.ink);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.globalAlpha = 1.0;

                    let p = Math.max(0, Math.min(100, pct));
                    if (p > 0.1) {
                        ctx.strokeStyle = _theme.hexOf(root.accent);
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + (p / 100) * Math.PI * 2);
                        ctx.stroke();
                    }
                }
            }

            // Spinning record.
            Item {
                id: disc
                width: root.s(300)
                height: width
                anchors.centerIn: parent

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                    running: root.playing
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.surface
                    border.width: root.s(1)
                    border.color: root.hairline
                }

                Canvas {
                    id: grooves
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: _theme
                        function onPaletteApplied() { grooves.requestPaint(); }
                    }

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();
                        let cx = width / 2;
                        let cy = height / 2;
                        let maxR = Math.min(cx, cy) - root.s(2);
                        ctx.lineWidth = Math.max(1, root.s(1));
                        ctx.strokeStyle = _theme.mix(root.ink, root.surface, 0.90);
                        for (let i = 1; i <= 30; i++) {
                            let r = maxR * i / 30;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.stroke();
                        }
                    }
                }

                Rectangle {
                    id: coverMask
                    anchors.centerIn: parent
                    width: root.s(118)
                    height: width
                    radius: width / 2
                    color: "white"
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.s(118)
                    height: width
                    radius: width / 2
                    color: root.surfaceHi
                    visible: coverImg.status !== Image.Ready
                    border.width: root.s(1)
                    border.color: root.hairline
                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: root.muted
                        font.family: root.mono
                        font.pixelSize: root.s(34)
                    }
                }

                Image {
                    id: coverImg
                    anchors.centerIn: parent
                    width: root.s(118)
                    height: width
                    source: root.coverSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.s(118)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: root.s(2)
                    border.color: root.hairline
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.s(10)
                    height: width
                    radius: width / 2
                    color: root.base
                    border.width: root.s(2)
                    border.color: root.hairline
                }
            }

            // Tonearm: the play/pause state in physical form.
            Item {
                id: tonearm
                width: root.s(70)
                height: root.s(210)
                x: discWrap.width - root.s(66)
                y: root.s(6)
                rotation: root.playing ? 24 : 14
                transformOrigin: Item.Top
                Behavior on rotation {
                    NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.s(2)
                    width: root.s(26)
                    height: width
                    radius: width / 2
                    color: root.surfaceHi
                    border.width: root.s(1)
                    border.color: root.hairline
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.s(20)
                    width: root.s(4)
                    height: root.s(168)
                    radius: root.s(2)
                    color: root.ink
                    opacity: 0.9
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.s(184)
                    width: root.s(24)
                    height: root.s(34)
                    radius: root.s(7)
                    color: root.surfaceHi
                    border.width: root.s(1)
                    border.color: root.hairline
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.s(10)
                        height: root.s(16)
                        radius: root.s(2)
                        color: root.accent2
                        opacity: 0.85
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                Text {
                    text: "33 ⅓ RPM"
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(8)
                    font.letterSpacing: root.s(1.5)
                }
                Item { width: Math.max(0, parent.width - root.s(150)) }
                Text {
                    text: "STEREO"
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(8)
                    font.letterSpacing: root.s(1.5)
                }
            }
        }

        // Metadata + controls.
        ColumnLayout {
            id: info
            anchors.left: discWrap.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.s(26)
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)
                Text {
                    text: "NOW PLAYING"
                    color: root.accent
                    font.family: root.mono
                    font.pixelSize: root.s(9)
                    font.bold: true
                    font.letterSpacing: root.s(2.2)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.musicData.source || ""
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(9)
                    font.letterSpacing: root.s(1.5)
                    elide: Text.ElideRight
                    Layout.maximumWidth: root.s(120)
                    horizontalAlignment: Text.AlignRight
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: root.s(10)
                text: root.musicData.title || "Not Playing"
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.s(38)
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: root.s(-0.5)
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 0.92
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: root.s(6)
                text: root.musicData.artist || ""
                color: root.ink
                font.family: root.mono
                font.pixelSize: root.s(15)
                font.letterSpacing: root.s(0.8)
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: root.s(9)
                text: root.musicData.deviceName
                    ? "OUTPUT · " + root.musicData.deviceName : ""
                color: root.muted
                font.family: root.mono
                font.pixelSize: root.s(10)
                font.letterSpacing: root.s(1.4)
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(7)
                Text {
                    text: root.musicData.positionStr || "00:00"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: root.s(27)
                    font.bold: true
                    font.letterSpacing: root.s(-0.5)
                }
                Text {
                    text: "/"
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(12)
                }
                Text {
                    text: root.musicData.lengthStr || "00:00"
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(11)
                    font.letterSpacing: root.s(1)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: root.s(7)
                Layout.preferredHeight: root.s(18)

                Rectangle {
                    id: progressTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: root.s(3)
                    radius: height / 2
                    color: root.surfaceHi
                }
                Rectangle {
                    anchors.verticalCenter: progressTrack.verticalCenter
                    width: progressTrack.width * root.displayPct / 100
                    height: progressTrack.height
                    radius: height / 2
                    color: root.accent
                }
                Rectangle {
                    width: root.s(9)
                    height: width
                    rotation: 45
                    anchors.verticalCenter: progressTrack.verticalCenter
                    x: progressTrack.width * root.displayPct / 100 - width / 2
                    color: root.ink
                    border.width: root.s(2)
                    border.color: root.base
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => {
                        root.seeking = true;
                        root.seekPct = root.pctFromX(mouse.x, width);
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) root.seekPct = root.pctFromX(mouse.x, width);
                    }
                    onReleased: {
                        root.seekTo(root.seekPct / 100);
                        seekReset.restart();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: root.s(15)
                spacing: root.s(11)

                Item {
                    width: root.s(38)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: prevMouse.containsMouse ? root.surfaceHi : "transparent"
                        border.width: root.s(1)
                        border.color: root.hairline
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: root.s(15)
                    }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.control("prev")
                    }
                }

                Item {
                    width: root.s(56)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: playMouse.containsMouse ? root.accent2 : root.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.playing ? "⏸" : "▶"
                        color: root.base
                        font.family: root.mono
                        font.pixelSize: root.s(root.playing ? 16 : 20)
                        font.bold: true
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlay()
                    }
                }

                Item {
                    width: root.s(38)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: nextMouse.containsMouse ? root.surfaceHi : "transparent"
                        border.width: root.s(1)
                        border.color: root.hairline
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: root.s(15)
                    }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.control("next")
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: root.s(1)
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "OUTPUT"
                        color: root.muted
                        font.family: root.mono
                        font.pixelSize: root.s(8)
                        font.letterSpacing: root.s(1.6)
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: root.musicData.deviceName || "Speaker"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: root.s(10)
                        font.letterSpacing: root.s(1)
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.s(128)
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: root.musicData.source ? "VIA " + root.musicData.source : ""
                        color: root.accent
                        font.family: root.mono
                        font.pixelSize: root.s(8)
                        font.letterSpacing: root.s(1)
                    }
                }
            }
        }
    }

    // ── equalizer ────────────────────────────────────────────────────────────
    Rectangle {
        id: eqPanel
        anchors.left: panel.left
        anchors.right: panel.right
        anchors.bottom: panel.bottom
        anchors.margins: root.s(3)
        height: root.s(152)
        radius: root.s(17)
        color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.62)
        border.width: root.s(1)
        border.color: root.hairline

        Item {
            id: eqHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.s(20)
            height: root.s(24)

            RowLayout {
                anchors.fill: parent
                spacing: root.s(10)

                Text {
                    text: "EQUALIZER"
                    color: root.muted
                    font.family: root.mono
                    font.pixelSize: root.s(9)
                    font.letterSpacing: root.s(2.2)
                }
                Text {
                    text: root.eqData.preset || "Flat"
                    color: root.accent2
                    font.family: root.mono
                    font.pixelSize: root.s(9)
                    font.bold: true
                    Layout.leftMargin: root.s(6)
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: root.s(5)
                    Repeater {
                        model: ["Flat", "Bass", "Vocal", "Rock"]
                        delegate: Rectangle {
                            width: root.s(42)
                            height: root.s(20)
                            radius: root.s(2)
                            color: root.eqData.preset === modelData ? root.accent : "transparent"
                            border.width: root.s(1)
                            border.color: root.eqData.preset === modelData ? root.accent : root.hairline
                            Text {
                                anchors.centerIn: parent
                                text: String(modelData).toUpperCase()
                                color: root.eqData.preset === modelData ? root.base : root.muted
                                font.family: root.mono
                                font.pixelSize: root.s(7)
                                font.letterSpacing: root.s(0.8)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyPreset(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    width: root.s(54)
                    height: root.s(20)
                    radius: root.s(2)
                    color: root.eqData.pending === true ? root.accent : "transparent"
                    border.width: root.s(1)
                    border.color: root.eqData.pending === true ? root.accent : root.hairline
                    Text {
                        anchors.centerIn: parent
                        text: "APPLY"
                        color: root.eqData.pending === true ? root.base : root.muted
                        font.family: root.mono
                        font.pixelSize: root.s(7)
                        font.letterSpacing: root.s(1)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyEq()
                    }
                }
            }
        }

        RowLayout {
            id: bands
            anchors.top: eqHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.s(20)
            anchors.rightMargin: root.s(20)
            anchors.topMargin: root.s(6)
            anchors.bottomMargin: root.s(10)
            spacing: root.s(10)

            Repeater {
                model: 10
                delegate: Item {
                    id: band
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property int bandIndex: index
                    property real bandValue: Number(root.eqData["b" + (index + 1)]) || 0
                    readonly property real norm: Math.max(0, Math.min(1, (bandValue + 12) / 24))

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: root.s(3)

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: root.s(2)
                                color: root.surfaceHi
                                opacity: 0.45
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * band.norm
                                radius: root.s(2)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: root.accent2 }
                                    GradientStop { position: 1; color: root.accent }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeVerCursor
                                onPressed: (mouse) =>
                                    root.setBandValue(band.bandIndex, 1 - mouse.y / height)
                                onPositionChanged: (mouse) => {
                                    if (pressed)
                                        root.setBandValue(band.bandIndex, 1 - mouse.y / height);
                                }
                                onReleased: root.commitBand(band.bandIndex)
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: band.bandValue
                            color: root.muted
                            font.family: root.mono
                            font.pixelSize: root.s(7)
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"][band.bandIndex]
                            color: root.muted
                            font.family: root.mono
                            font.pixelSize: root.s(7)
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }
}
