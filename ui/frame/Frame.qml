import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../core"
import "../../core/FrameGeometry.js" as FG
import "../../core/WindowRegistry.js" as Registry
import "../bar"

// ═══════════════════════════════════════════════════════════════════════════
// Frame — screen frame (settings.json "frame").
//
// A border that wraps all four screen edges, drawn on the Bottom layer (behind
// the bar, the mascot islands and windows) and reserving space on every side
// so windows never cross it (same model as the bar). Where the bar, the nyx
// island or an edge-anchored widget (launcher/panels) meet the frame, the line
// sinks and hugs them with rounded corners (muescas), and it morphs live while
// the launcher/panels open and close.
//
// One drawing surface per screen + up to four transparent "strut" surfaces
// that reserve the edge bands. Layer-shell cannot reserve all four sides from a
// single surface (exclusiveZone needs 1 or 3 anchors), hence the split.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root

    // ---- config: ONE watcher for the whole frame (no per-screen processes) ----
    // FileView follows settings.json across atomic (tmp + mv) writes, so both
    // the editor panel and external edits apply live.
    property var frameRaw: ({})
    property var barCfg: ({})
    property var mascotsCfg: ({})
    property real uiScale: 1.0
    readonly property var fcfg: FG.normalize(frameRaw)

    function applySettings(t) {
        if (!t) return;
        try {
            let p = JSON.parse(t);
            root.frameRaw = (p.frame && typeof p.frame === "object") ? p.frame : ({});
            root.barCfg = p.bar || ({});
            root.mascotsCfg = p.mascots || ({});
            root.uiScale = (p.uiScale !== undefined) ? p.uiScale : 1.0;
        } catch (e) {}
    }

    // One read + one watch for the whole frame (no per-screen processes).
    // FileView only detects changes (reliable across atomic tmp+mv writes); the
    // Process performs the read (FileView.text() is not reliable at startup).
    Process {
        id: reader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.applySettings(this.text)
        }
    }
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/hypr/settings.json"
        watchChanges: true
        onFileChanged: { reader.running = false; reader.running = true; }
    }

    // Process/FileView above are normal children of this Item; the per-screen
    // windows live under Variants (children of Variants are NOT instantiated).
    Variants {
    model: Quickshell.screens
    delegate: Component {
        Item {
            id: scr
            required property var modelData

            readonly property real sw: modelData ? modelData.width : 1920
            readonly property real sh: modelData ? modelData.height : 1080

            // ---- config (shared, from the root watcher) ----
            readonly property var fcfg: root.fcfg
            readonly property var barCfg: root.barCfg
            readonly property var mcfg: root.mascotsCfg
            property real uiScale: root.uiScale

            readonly property real sc: Registry.getScale(sw, sh, uiScale)

            // Scaled copy of the frame config (design px -> device px).
            readonly property var gcfg: ({
                enabled: fcfg.enabled,
                thickness: fcfg.thickness * sc,
                sideThickness: fcfg.sideThickness * sc,
                radius: fcfg.radius * sc,
                inset: fcfg.inset * sc,
                gap: fcfg.gap * sc,
                color: fcfg.color,
                alpha: fcfg.alpha,
                line: fcfg.line,
                lineWidth: fcfg.lineWidth * sc,
                fill: fcfg.fill,
                fillColor: fcfg.fillColor,
                fillAlpha: fcfg.fillAlpha,
                reserve: fcfg.reserve,
                reserveExtra: fcfg.reserveExtra * sc,
                notchRadius: fcfg.notchRadius * sc,
                notchBar: fcfg.notchBar,
                notchWidget: fcfg.notchWidget,
                notchMascot: fcfg.notchMascot,
                widgetReach: fcfg.widgetReach * sc,
                layer: fcfg.layer
            })

            readonly property bool on: fcfg.enabled === true

            // ---- geometry ----
            readonly property var obstacles: {
                var out = [];
                var g = gcfg;

                // Bar: full-width band on its edge; shifts the frame base there.
                if (g.notchBar && barCfg && barCfg.position) {
                    var t = ((barCfg.thickness !== undefined ? barCfg.thickness : 48)) * sc;
                    var e = ((barCfg.edgeGap !== undefined ? barCfg.edgeGap : 8)) * sc;
                    var inner = e + t;
                    var p = barCfg.position;
                    if (p === "top") out.push({ edge: "top", a: -1, b: sw + 1, depth: inner });
                    else if (p === "bottom") out.push({ edge: "bottom", a: -1, b: sw + 1, depth: sh - inner });
                    else if (p === "left") out.push({ edge: "left", a: -1, b: sh + 1, depth: inner });
                    else if (p === "right") out.push({ edge: "right", a: -1, b: sh + 1, depth: sw - inner });
                }

                // Active widget (launcher/panels): live box from FrameBus.
                if (g.notchWidget) {
                    var b = FrameBus.active;
                    if (b && b.valid && b.edge && b.edge !== "") {
                        if (b.edge === "top") out.push({ edge: "top", a: b.x, b: b.x + b.w, depth: b.y + b.h });
                        else if (b.edge === "bottom") out.push({ edge: "bottom", a: b.x, b: b.x + b.w, depth: b.y });
                        else if (b.edge === "left") out.push({ edge: "left", a: b.y, b: b.y + b.h, depth: b.x + b.w });
                        else if (b.edge === "right") out.push({ edge: "right", a: b.y, b: b.y + b.h, depth: b.x });
                    }
                }

                // Mascot island/notch: approximated from its settings.
                if (g.notchMascot && mcfg && mcfg.enabled === true) {
                    var mo = mascotObstacle(g, mcfg, sw, sh, sc);
                    if (mo) out.push(mo);
                }
                return out;
            }

            // The frame is a bezel: a clean outer contour at the screen edge
            // (inset) and a hugging inner contour (inset + thickness) that sinks
            // around the bar/mascot/launcher. The band fills between them; the
            // line is the inner contour.
            readonly property string framePath: FG.buildInnerPath(sw, sh, gcfg, obstacles)
            readonly property string bandPath: gcfg.fill ? FG.buildBandPath(sw, sh, gcfg, obstacles) : ""

            // Mirror nyx/front/MascotsOverlay.qml geometry so the bay matches the
            // real island/notch. `k` is the shell scale (overlay.s()).
            function mascotObstacle(g, m, width, height, k) {
                var pos = String(m.position || "top-center");
                var notch = String(m.appearance || "island").toLowerCase() === "notch";
                var count = Math.max(1, Math.min(3, Math.round(Number(m.count) || 1)));
                var scale = Math.min(1.6, Math.max(0.6, Number(m.size) || 1));
                var ns = Number(m.notchHeight) || 0;
                var nw = Number(m.notchWidth) || 260;
                var nOff = Number(m.notchOffset) || 0;
                var barThick = Number(m.barThickness) || 48;
                var barBottom = String(m.barPosition || "top") === "bottom";

                var pillW = (48 * k * count + 32 * k) * scale;
                var pillH = 46 * k * scale;
                // nyx: notchH = max(pillH + s(6), s(notchHeight)) when set.
                var notchH = notch
                    ? (ns > 0 ? Math.max(pillH + 6 * k, ns * k) : Math.max(pillH + 10 * k, 38 * k))
                    : pillH;
                var notchW = notch
                    ? Math.max(pillW + 20 * k, Math.min(width * 0.5, Math.max(80, nw) * k))
                    : pillW;
                var off = nOff * k;
                var edgeMargin = (barBottom ? 14 : barThick + 14) * k;

                function along(total, span) {
                    if (pos.indexOf("left") !== -1 && pos.indexOf("center") === -1) return { a: 0, b: Math.round(span) };
                    if (pos.indexOf("right") !== -1 && pos.indexOf("center") === -1) return { a: Math.round(total - span), b: Math.round(total) };
                    return { a: Math.round((total - span) / 2), b: Math.round((total + span) / 2) };
                }

                if (pos.indexOf("top") !== -1) {
                    var at = along(width, notchW);
                    var topDepth = notch ? (off + notchH) : (edgeMargin + pillH + off);
                    return { edge: "top", a: at.a, b: at.b, depth: topDepth };
                }
                if (pos.indexOf("bottom") !== -1) {
                    var ab = along(width, notchW);
                    var botDepth = notch ? (off + notchH) : (edgeMargin + pillH + off);
                    return { edge: "bottom", a: ab.a, b: ab.b, depth: height - botDepth };
                }
                if (pos.indexOf("left") !== -1) {
                    var al = along(height, notchH);
                    var lDepth = notch ? (off + notchW) : (edgeMargin + pillW + off);
                    return { edge: "left", a: al.a, b: al.b, depth: lDepth };
                }
                if (pos.indexOf("right") !== -1) {
                    var ar = along(height, notchH);
                    var rDepth = notch ? (off + notchW) : (edgeMargin + pillW + off);
                    return { edge: "right", a: ar.a, b: ar.b, depth: width - rDepth };
                }
                return null;
            }

            // ---- palette ----
            Colors { id: pal }

            function roleColor(role) {
                if (!role) return pal.overlay0;
                var s = String(role);
                if (s.charAt(0) === "#") return Qt.color(s);
                var c = pal[s];
                return (c !== undefined && c !== null) ? c : pal.overlay0;
            }

            function withAlpha(c, a) {
                var col = (typeof c === "string") ? Qt.color(c) : c;
                return Qt.rgba(col.r, col.g, col.b, a);
            }

            readonly property color frameColor: withAlpha(roleColor(gcfg.color), gcfg.alpha)
            readonly property color bandColor: withAlpha(roleColor(gcfg.fillColor), gcfg.fillAlpha)

            // ---- reservation ----
            // Edge the nyx notch already reserves (mirrors MascotsOverlay: notch
            // mode + notchReserve + enabled). The frame must not reserve it too,
            // or the compositor stacks the zones and pushes the notch down.
            readonly property string mascotEdge: {
                var m = mcfg;
                if (m && m.enabled === true
                    && String(m.appearance || "island").toLowerCase() === "notch"
                    && m.notchReserve === true) {
                    var pos = String(m.position || "top-center");
                    if (pos.indexOf("top") !== -1) return "top";
                    if (pos.indexOf("bottom") !== -1) return "bottom";
                    if (pos.indexOf("left") !== -1) return "left";
                    if (pos.indexOf("right") !== -1) return "right";
                }
                return "";
            }
            readonly property var reserveEdges: FG.reserveEdges(gcfg, barCfg ? barCfg.position : "", mascotEdge)
            readonly property real reservePx: FG.reservePx(gcfg)
            function reserves(edge) {
                return on && gcfg.reserve && reservePx > 0 && reserveEdges.indexOf(edge) !== -1;
            }

            // ================================================================
            // DRAWING SURFACE
            // ================================================================
            PanelWindow {
                id: drawWin
                visible: scr.on && scr.framePath !== ""
                screen: scr.modelData
                color: "transparent"

                WlrLayershell.namespace: "qs-screen-frame"
                WlrLayershell.layer: scr.gcfg.layer === "background" ? WlrLayer.Background : WlrLayer.Bottom

                exclusionMode: ExclusionMode.Ignore
                focusable: false

                anchors { top: true; bottom: true; left: true; right: true }
                implicitWidth: scr.sw
                implicitHeight: scr.sh

                // Only the border band is interactive; the centre passes through.
                readonly property real band: Math.max(scr.gcfg.thickness + 2,
                                                       scr.gcfg.inset + scr.gcfg.thickness + 2)
                mask: Region {
                    Region { x: 0; y: 0; width: drawWin.width; height: drawWin.band }
                    Region { x: 0; y: drawWin.height - drawWin.band; width: drawWin.width; height: drawWin.band }
                    Region { x: 0; y: 0; width: drawWin.band; height: drawWin.height }
                    Region { x: drawWin.width - drawWin.band; y: 0; width: drawWin.band; height: drawWin.height }
                }

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    visible: scr.gcfg.thickness > 0 || scr.gcfg.line

                    // Filled border band (even-odd: outer contour minus inner).
                    ShapePath {
                        fillColor: scr.gcfg.fill ? scr.bandColor : "transparent"
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillRule: ShapePath.OddEvenFill
                        PathSvg { path: scr.bandPath }
                    }

                    // Inner border line (the one that hugs).
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: scr.gcfg.line ? scr.frameColor : "transparent"
                        strokeWidth: scr.gcfg.lineWidth
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.MiterJoin
                        PathSvg { path: scr.framePath }
                    }
                }
            }

            // ================================================================
            // RESERVATION STRUTS (one per edge; skip the bar's edge)
            // ================================================================
            PanelWindow {
                visible: scr.reserves("top")
                screen: scr.modelData
                color: "transparent"
                WlrLayershell.namespace: "qs-screen-frame-strut"
                WlrLayershell.layer: WlrLayer.Top
                anchors { top: true; left: true; right: true }
                implicitHeight: scr.reservePx
                exclusiveZone: scr.reserves("top") ? scr.reservePx : 0
                exclusionMode: ExclusionMode.Normal
                focusable: false
                mask: Region {}
            }
            PanelWindow {
                visible: scr.reserves("bottom")
                screen: scr.modelData
                color: "transparent"
                WlrLayershell.namespace: "qs-screen-frame-strut"
                WlrLayershell.layer: WlrLayer.Top
                anchors { bottom: true; left: true; right: true }
                implicitHeight: scr.reservePx
                exclusiveZone: scr.reserves("bottom") ? scr.reservePx : 0
                exclusionMode: ExclusionMode.Normal
                focusable: false
                mask: Region {}
            }
            PanelWindow {
                visible: scr.reserves("left")
                screen: scr.modelData
                color: "transparent"
                WlrLayershell.namespace: "qs-screen-frame-strut"
                WlrLayershell.layer: WlrLayer.Top
                anchors { left: true; top: true; bottom: true }
                implicitWidth: scr.reservePx
                exclusiveZone: scr.reserves("left") ? scr.reservePx : 0
                exclusionMode: ExclusionMode.Normal
                focusable: false
                mask: Region {}
            }
            PanelWindow {
                visible: scr.reserves("right")
                screen: scr.modelData
                color: "transparent"
                WlrLayershell.namespace: "qs-screen-frame-strut"
                WlrLayershell.layer: WlrLayer.Top
                anchors { right: true; top: true; bottom: true }
                implicitWidth: scr.reservePx
                exclusiveZone: scr.reserves("right") ? scr.reservePx : 0
                exclusionMode: ExclusionMode.Normal
                focusable: false
                mask: Region {}
            }
        }
    }
    }
}
