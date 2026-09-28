import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "MascotMetrics.js" as Metrics

// ═══════════════════════════════════════════════════════════════════════════
// MascotsOverlay — standalone mascot island for Quickshell (Hyprland).
//
// This file and its siblings (Mascot.qml, <Species>Mascot.qml, MascotFaceEyes,
// MascotDock) form a self-contained module that never imports the shell: the
// palette, the settings path and the widget hooks are injected.
//
// Public API (per screen):
//   enabled            master switch (also read from the settings file)
//   species            "flame" | "cat" | "dog" | "eyes" | "mixed"
//   count              1..3 mascots in the island
//   size               0.6..1.6 mascot scale
//   uiScale            extra user scale (the shell's uiScale)
//   position           top-left | top-center | top-right | center-left |
//                      center | center-right | bottom-left | bottom-center |
//                      bottom-right (the dock unfolds toward the screen centre)
//   barPosition        "top" | "bottom" | other (edge margin for the island)
//   barThickness       bar thickness in px (edge margin)
//   palette            { base, surface1, text, crust, red, yellow, green,
//                        blue, mauve, glassOn } — falls back to Catppuccin
//   settingsPath       optional settings.json to watch ("mascots", "uiScale",
//                        "bar.position", "bar.thickness" keys)
//   widgetStatePath    optional file with the current widget name
//   dockWidgetName     widget name that hides the island entirely
//   widgetRectProvider function(name, sw, sh, uiScale) -> { x, y, w, h } | null
//   widgetList         [{ id, label, icon }] shown in the click dock
//   widgetLauncher     function(id) called when a dock card is clicked
//
// Behaviour:
//   - Pupils track the cursor (hyprctl cursorpos; offset proportional to the
//     eye size, so tracking reads at any scale).
//   - Hovering the island surprises the mascots; they calm down on leave.
//   - Clicking the island unfolds a dock with widget miniatures (3 per page);
//     picking one launches it through `widgetLauncher` and the mascots cheer.
//   - Random moods (angry / surprised / happy / sleepy, staggered per mascot)
//     on window open/close (Hyprland socket2) and widget open/close; asleep
//     after 30 s idle.
//   - The island fades away while the dock widget is open or any occluder
//     overlaps it, and fades back in afterwards.
//   - Only the island and the open dock capture input; the rest of the
//     surface stays click-through through a two-region mask.
// ═══════════════════════════════════════════════════════════════════════════

Variants {
    id: root
    model: Quickshell.screens

    // ── public API ─────────────────────────────────────────────────────────
    property bool enabled: false
    property string species: "flame"
    property int count: 3
    property real size: 1.0
    property real uiScale: 1.0
    property string position: "top-center"
    property string barPosition: "top"
    property real barThickness: 48
    property var palette: ({
        base: "#1e1e2e", surface1: "#45475a", text: "#cdd6f4",
        crust: "#11111b", red: "#f38ba8", yellow: "#f9e2af",
        green: "#a6e3a1", blue: "#89b4fa", mauve: "#cba6f7",
        glassOn: false
    })
    property string settingsPath: ""
    property string widgetStatePath: ""
    property string dockWidgetName: ""
    property var widgetRectProvider: null
    property var widgetList: []
    property var widgetLauncher: null

    delegate: Component {
        PanelWindow {
            id: overlay

            required property var modelData
            screen: modelData

            // ── derived config ─────────────────────────────────────────────
            readonly property string speciesKind: {
                let v = String(root.species || "flame").toLowerCase();
                if (v === "classic") v = "flame";
                return ["flame", "cat", "dog", "eyes", "mixed"].indexOf(v) !== -1
                    ? v : "flame";
            }
            readonly property int mascotCount: Math.max(1, Math.min(3, Math.round(root.count)))
            readonly property real mascotScale: Math.max(0.6, Math.min(1.6, root.size))

            // Position model (same ids as the editor's position pad).
            readonly property bool posTop: String(root.position).indexOf("top-") === 0
            readonly property bool posBottom: String(root.position).indexOf("bottom-") === 0
            readonly property bool posLeft: String(root.position).indexOf("-left") !== -1
            readonly property bool posRight: String(root.position).indexOf("-right") !== -1
            readonly property bool panelBelow: !overlay.posBottom

            readonly property real boxMargin: overlay.s(14)
            readonly property real edge: overlay.s(14)
            readonly property real panelGap: overlay.s(8)

            // ── island / dock geometry ─────────────────────────────────────
            // One slot per mascot: 3 mascots = 176 design units.
            readonly property real pillW: (overlay.s(48) * overlay.mascotCount + overlay.s(32))
                * overlay.mascotScale
            readonly property real pillH: overlay.s(46) * overlay.mascotScale
            readonly property real panelW: dockPanel.panelWidth
            readonly property real panelH: dockPanel.panelHeight
            readonly property real panelShown: Math.max(0, dockPanel.reveal)
            readonly property real panelSpan: overlay.panelShown * (overlay.panelGap + overlay.panelH)
            readonly property real slotW: Math.max(overlay.pillW, overlay.panelW)

            implicitWidth: overlay.slotW + overlay.boxMargin * 2
            implicitHeight: overlay.boxMargin * 2 + overlay.pillH + overlay.panelSpan
            readonly property real frameX: overlay.posLeft ? overlay.boxMargin
                : overlay.posRight ? (overlay.implicitWidth - overlay.pillW - overlay.boxMargin)
                : Math.round((overlay.implicitWidth - overlay.pillW) / 2)
            readonly property real frameY: overlay.boxMargin + (overlay.panelBelow ? 0 : overlay.panelSpan)
            readonly property real panelX: Math.round(Math.max(0, Math.min(
                overlay.implicitWidth - overlay.panelW,
                overlay.frameX + overlay.pillW / 2 - overlay.panelW / 2)))
            readonly property real panelY: overlay.panelBelow
                ? overlay.frameY + overlay.pillH + overlay.panelGap
                : overlay.boxMargin
            // Screen-space origin of this surface (anchored edges have no
            // left/top margin, so the window top-left is computed instead).
            readonly property real originX: overlay.posRight
                ? (overlay.screen ? overlay.screen.width - overlay.implicitWidth
                    - overlay.margins.right : 0)
                : overlay.margins.left
            readonly property real originY: overlay.posBottom
                ? (overlay.screen ? overlay.screen.height - overlay.implicitHeight
                    - overlay.margins.bottom : 0)
                : overlay.margins.top

            anchors.top: !overlay.posBottom
            anchors.bottom: overlay.posBottom
            anchors.left: !overlay.posRight
            anchors.right: overlay.posRight
            margins.top: !overlay.posBottom
                ? Math.max(0, Math.round((overlay.posTop
                    ? (overlay.barPosition === "top"
                        ? overlay.s(overlay.barThickness) + overlay.s(14) : overlay.s(14))
                    : (overlay.screen.height - overlay.implicitHeight) / 2) - overlay.boxMargin))
                : 0
            margins.bottom: overlay.posBottom
                ? Math.max(0, Math.round((overlay.barPosition === "bottom"
                    ? overlay.s(overlay.barThickness) + overlay.s(14) : overlay.s(14))
                    - overlay.boxMargin))
                : 0
            margins.left: overlay.posLeft ? Math.max(0, overlay.edge - overlay.boxMargin)
                : overlay.posRight ? 0
                : Math.max(0, Math.round((overlay.screen.width - overlay.implicitWidth) / 2))
            margins.right: overlay.posRight ? Math.max(0, overlay.edge - overlay.boxMargin) : 0

            color: "transparent"
            WlrLayershell.namespace: "qs-mascots"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            focusable: false

            // Input mask: the island always, the dock while it is unfolded.
            mask: Region {
                Region {
                    x: Math.round(overlay.frameX - overlay.s(2))
                    y: Math.round(overlay.frameY - overlay.s(2))
                    width: overlay.shown ? Math.round(overlay.pillW + overlay.s(4)) : 0
                    height: overlay.shown ? Math.round(overlay.pillH + overlay.s(4)) : 0
                    radius: Math.round(overlay.pillH / 2 + overlay.s(2))
                }
                Region {
                    x: Math.round(overlay.panelX)
                    y: Math.round(overlay.panelY)
                    width: overlay.panelShown > 0.001 ? Math.round(overlay.panelW) : 0
                    height: overlay.panelShown > 0.001
                        ? Math.round(overlay.panelH * overlay.panelShown) : 0
                    radius: overlay.s(14)
                }
            }

            // ── scale ──────────────────────────────────────────────────────
            readonly property real baseScale: Metrics.getScale(
                overlay.screen ? overlay.screen.width : 1920,
                overlay.screen ? overlay.screen.height : 1080,
                root.uiScale)
            function s(v) { return Metrics.s(v, overlay.baseScale) }

            // ── settings.json adapter (optional) ───────────────────────────
            function applySettings(txt) {
                try {
                    let p = JSON.parse(txt);
                    let m = (p.mascots && typeof p.mascots === "object") ? p.mascots : {};
                    if (m.enabled !== undefined) root.enabled = m.enabled === true;
                    if (m.size !== undefined) root.size = m.size;
                    if (m.species !== undefined) root.species = m.species;
                    if (m.count !== undefined) root.count = m.count;
                    if (m.position !== undefined) root.position = m.position;
                    if (p.uiScale !== undefined) root.uiScale = p.uiScale;
                    let b = p.bar || {};
                    if (b.position) root.barPosition = b.position;
                    if (b.thickness) root.barThickness = b.thickness;
                } catch (e) {}
            }
            Loader {
                active: root.settingsPath !== ""
                sourceComponent: settingsAdapter
            }
            Component {
                id: settingsAdapter
                Item {
                    Process {
                        id: settingsCat
                        command: ["cat", root.settingsPath]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: overlay.applySettings(this.text)
                        }
                    }
                    FileView {
                        path: root.settingsPath
                        watchChanges: true
                        blockLoading: true
                        onFileChanged: settingsCat.running = true
                    }
                }
            }

            // ── widget occlusion (optional, injected) ──────────────────────
            property string currentWidget: ""
            readonly property bool dockOpen: overlay.currentWidget !== ""
                && overlay.currentWidget === root.dockWidgetName
            function widgetOverlaps() {
                if (overlay.currentWidget === "" || overlay.currentWidget === "hidden"
                    || overlay.currentWidget === root.dockWidgetName) return false;
                if (!root.widgetRectProvider) return false;
                let t = null;
                try {
                    t = root.widgetRectProvider(overlay.currentWidget,
                        overlay.screen ? overlay.screen.width : 1920,
                        overlay.screen ? overlay.screen.height : 1080,
                        root.uiScale);
                } catch (e) { t = null; }
                if (!t) return false;
                let m = overlay.s(12);
                let ax = (overlay.screen ? overlay.screen.x : 0) + overlay.originX
                    + overlay.frameX - m;
                let ay = (overlay.screen ? overlay.screen.y : 0) + overlay.originY
                    + overlay.frameY - m;
                let aw = overlay.pillW + 2 * m;
                let ah = overlay.pillH + 2 * m;
                let bx = t.x !== undefined ? t.x : 0;
                let by = t.y !== undefined ? t.y : 0;
                return !(bx + t.w < ax || bx > ax + aw || by + t.h < ay || by > ay + ah);
            }
            readonly property bool blocked: overlay.dockOpen || overlay.widgetOverlaps()
            readonly property bool shown: root.enabled && !overlay.blocked
            readonly property bool mascotsShown: overlay.shown && !overlay.panelOpen

            Loader {
                active: root.widgetStatePath !== ""
                sourceComponent: widgetAdapter
            }
            Component {
                id: widgetAdapter
                Item {
                    Process {
                        id: widgetCat
                        command: ["cat", root.widgetStatePath]
                        running: false
                        stdout: StdioCollector {
                            onStreamFinished: overlay.applyWidget(this.text.trim())
                        }
                    }
                    FileView {
                        path: root.widgetStatePath
                        watchChanges: true
                        blockLoading: true
                        onFileChanged: widgetCat.running = true
                    }
                    Component.onCompleted: widgetCat.running = true
                }
            }
            function applyWidget(name) {
                let prev = overlay.currentWidget;
                if (name === prev) return;
                overlay.currentWidget = name;
                let opened = name !== "" && name !== "hidden";
                let closed = prev !== "" && prev !== "hidden" && !opened;
                if (opened || closed) {
                    overlay.react();
                    idleTimer.restart();
                }
            }

            // ── dock panel ─────────────────────────────────────────────────
            property bool panelOpen: false
            function togglePanel() { overlay.panelOpen = !overlay.panelOpen; }
            function launchWidget(id) {
                overlay.panelOpen = false;
                overlay.setAllMoods("happy");
                if (root.widgetLauncher) root.widgetLauncher(id);
            }

            // ── cursor (Hyprland) ──────────────────────────────────────────
            property real cursorX: 0
            property real cursorY: 0
            property bool cursorHere: false
            Process {
                id: cursorProc
                command: ["bash", "-c", "while true; do hyprctl cursorpos 2>/dev/null; sleep 0.06; done"]
                running: root.enabled
                stdout: SplitParser { onRead: data => overlay.updateCursor(data) }
            }
            function updateCursor(line) {
                let p = String(line).split(",");
                if (p.length < 2) return;
                let x = parseFloat(p[0]);
                let y = parseFloat(p[1]);
                if (isNaN(x) || isNaN(y)) return;
                let sx = overlay.screen ? overlay.screen.x : 0;
                let sy = overlay.screen ? overlay.screen.y : 0;
                overlay.cursorX = x;
                overlay.cursorY = y;
                let sw = overlay.screen ? overlay.screen.width : overlay.width;
                let sh = overlay.screen ? overlay.screen.height : overlay.height;
                overlay.cursorHere = x >= sx && x < sx + sw && y >= sy && y < sy + sh;
                if (overlay.cursorHere) idleTimer.restart();
            }

            // ── window events (Hyprland socket2) ───────────────────────────
            Process {
                id: eventsProc
                command: ["bash", "-c",
                    "SOCK=\"${XDG_RUNTIME_DIR:-/tmp}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\"; " +
                    "while true; do socat -u UNIX-CONNECT:$SOCK - 2>/dev/null; sleep 0.5; done"]
                running: root.enabled
                stdout: SplitParser { onRead: data => overlay.handleEvent(data) }
            }
            function handleEvent(line) {
                let s = String(line);
                if (s.indexOf("openwindow>>") === 0 || s.indexOf("closewindow>>") === 0) {
                    overlay.react();
                } else if (s.indexOf("activewindow>>") === 0) {
                    overlay.pickMood(Math.floor(Math.random() * overlay.mascotCount));
                }
                idleTimer.restart();
            }

            // ── moods (per mascot, staggered random reactions) ──────────────
            property var moods: ["idle", "idle", "idle"]
            function setAllMoods(m) {
                let arr = [];
                for (let i = 0; i < overlay.mascotCount; i++) arr.push(m);
                overlay.moods = arr;
            }
            function pickMood(i) {
                let pool = ["angry", "surprised", "angry", "surprised", "happy", "sleepy"];
                let m = pool[Math.floor(Math.random() * pool.length)];
                let arr = overlay.moods.slice();
                arr[i] = m;
                overlay.moods = arr;
                moodTimer.restart();
            }
            function react() {
                let timers = [reactTimer0, reactTimer1, reactTimer2];
                for (let i = 0; i < overlay.mascotCount; i++) {
                    let t = timers[i];
                    if (t) { t.interval = 60 + Math.round(Math.random() * 320); t.restart(); }
                }
            }
            function hoverReaction(on) {
                if (on) {
                    overlay.setAllMoods("surprised");
                    idleTimer.restart();
                } else {
                    overlay.setAllMoods("idle");
                }
            }
            Timer { id: reactTimer0; onTriggered: overlay.pickMood(0) }
            Timer { id: reactTimer1; onTriggered: overlay.pickMood(1) }
            Timer { id: reactTimer2; onTriggered: overlay.pickMood(2) }
            Timer {
                id: moodTimer
                interval: 1700
                onTriggered: overlay.setAllMoods("idle")
            }
            Timer {
                id: idleTimer
                interval: 30000
                onTriggered: overlay.setAllMoods("sleepy")
            }

            // Dominant mood drives the island accent line.
            readonly property string dominantMood: {
                let prio = ["angry", "surprised", "happy", "sleepy"];
                for (let p = 0; p < prio.length; p++)
                    for (let i = 0; i < overlay.moods.length; i++)
                        if (overlay.moods[i] === prio[p]) return prio[p];
                return "idle";
            }
            readonly property color accentColor: dominantMood === "angry" ? root.palette.red
                : dominantMood === "surprised" ? root.palette.yellow
                : dominantMood === "happy" ? root.palette.green
                : dominantMood === "sleepy" ? root.palette.blue
                : root.palette.mauve

            // ── mascot slots ───────────────────────────────────────────────
            readonly property real mascotSize: overlay.s(30) * overlay.mascotScale
            readonly property real zSize: overlay.s(11) * overlay.mascotScale
            property real clock: 0
            property var mpos: [
                { x: 30, y: 10, px: 0, py: 0 },
                { x: 90, y: 10, px: 0, py: 0 },
                { x: 150, y: 10, px: 0, py: 0 }
            ]

            Timer {
                interval: 16
                repeat: true
                running: root.enabled
                onTriggered: overlay.step()
            }

            function step() {
                overlay.clock += 1;
                let n = overlay.mascotCount;
                let arr = [];
                let sx = overlay.screen ? overlay.screen.x : 0;
                let sy = overlay.screen ? overlay.screen.y : 0;
                let lx = overlay.cursorX - sx;
                let ly = overlay.cursorY - sy;
                for (let i = 0; i < n; i++) {
                    let cur = overlay.mpos[i] || { x: overlay.frameX + i * 40, y: overlay.frameY, px: 0, py: 0 };
                    let tx = overlay.frameX + overlay.pillW * (i + 0.5) / n - overlay.mascotSize / 2;
                    let ty = overlay.frameY + overlay.pillH / 2 - overlay.mascotSize * 0.55;
                    let nx = cur.x + (tx - cur.x) * 0.13;
                    let ny = cur.y + (ty - cur.y) * 0.13;
                    // Look direction: unit vector from the mascot centre in
                    // SCREEN coordinates to the cursor (the window margins are
                    // part of the screen position; without them the eyes only
                    // track one half of the screen). Smoothed per tick.
                    let tpx = 0, tpy = 0;
                    if (overlay.cursorHere) {
                        let cxp = overlay.originX + nx + overlay.mascotSize / 2;
                        let cyp = overlay.originY + ny + overlay.mascotSize / 2;
                        let vx = lx - cxp, vy = ly - cyp;
                        let d = Math.max(1, Math.sqrt(vx * vx + vy * vy));
                        tpx = vx / d;
                        tpy = vy / d;
                    }
                    let px = (cur.px || 0) + (tpx - (cur.px || 0)) * 0.28;
                    let py = (cur.py || 0) + (tpy - (cur.py || 0)) * 0.28;
                    arr.push({ x: nx, y: ny, px: px, py: py });
                }
                overlay.mpos = arr;
            }

            // ── island ─────────────────────────────────────────────────────
            Rectangle {
                id: frame
                x: overlay.frameX
                y: overlay.frameY
                width: overlay.pillW
                height: overlay.pillH
                radius: height / 2
                visible: opacity > 0.01
                opacity: overlay.shown ? 1.0 : 0.0
                scale: overlay.shown ? 1.0 : 0.78
                color: Qt.rgba(root.palette.base.r, root.palette.base.g,
                               root.palette.base.b,
                               root.palette.glassOn === true
                                   ? Math.min(0.95, root.palette.base.a + 0.05) : 1.0)
                border.width: 1
                border.color: Qt.alpha(root.palette.surface1, 0.9)
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(overlay.accentColor, 0.45)
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                }
                // palette accent line (state colour)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: overlay.s(7)
                    width: parent.width * 0.22
                    height: overlay.s(3)
                    radius: height / 2
                    color: overlay.accentColor
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                // Click / hover (the pointer only reaches this surface inside
                // the island mask region).
                MouseArea {
                    id: islandMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: overlay.togglePanel()
                    onEntered: overlay.hoverReaction(true)
                    onExited: overlay.hoverReaction(false)
                }
            }

            // ── widget dock (unfolds from the island) ──────────────────────
            MascotDock {
                id: dockPanel
                x: overlay.panelX
                y: overlay.panelY
                width: overlay.panelW
                height: overlay.panelH
                open: overlay.panelOpen
                widgets: root.widgetList
                palette: root.palette
                scaleUnit: overlay.baseScale
                accent: overlay.accentColor
                onLaunchRequested: (id) => overlay.launchWidget(id)
                onCloseRequested: overlay.panelOpen = false
            }

            // ── mascots ────────────────────────────────────────────────────
            Repeater {
                model: overlay.mascotCount
                delegate: Mascot {
                    width: overlay.mascotSize
                    height: overlay.mascotSize * 1.18
                    opacity: overlay.mascotsShown ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    index: modelData
                    species: overlay.speciesKind
                    mood: overlay.moods[modelData] || "idle"
                    lookX: (overlay.mpos[modelData] || {}).px || 0
                    lookY: (overlay.mpos[modelData] || {}).py || 0
                    tint: [root.palette.mauve, root.palette.blue,
                           root.palette.green][modelData % 3]
                    crust: root.palette.crust
                    text: root.palette.text
                    red: root.palette.red
                    clock: overlay.clock
                    xPos: (overlay.mpos[modelData] || {}).x || 0
                    yPos: (overlay.mpos[modelData] || {}).y || 0
                    zSize: overlay.zSize
                }
            }
        }
    }
}
