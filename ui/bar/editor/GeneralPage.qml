import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"
import "../BarLayout.js" as BarLayout
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// GeneralPage — BarEditor tab: engine switcher (bar / classic).
//
// Fase 5 (look Guide): título s(24) Black + grid de OptionCards (template
// cards GP:1276-1302); sin filas con cajita decorativa. Con engine classic se
// añaden los EditorButton de acciones (llaman a las funciones del root:
// mirrorBarAction() / classicDefaultsAction()).
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors,
// bar.setEngine(), ...). NEVER touches ids of the editor root. Exposes the
// scroll Flickable via `flickable` so the root can drive DnD auto-scroll.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent   // Phase 3: el item del Loader ocupa la stage

    property var bar: null

    // ── Posiciones de popups (settings.widgets.<id>.position) ─────────────
    property int posTick: 0
    readonly property var widgetsList: [
        { id: "network", label: "Wifi / Bluetooth" },
        { id: "volume", label: "Sound" },
        { id: "battery", label: "Battery" },
        { id: "system-monitor", label: "System" },
        { id: "applauncher", label: "Launcher" },
        { id: "clipboard", label: "Clipboard" },
        { id: "calendar", label: "Timex" },
        { id: "music", label: "Music" },
        { id: "updater", label: "Updater" },
        { id: "guide", label: "About (guide)" },
        { id: "quicknotes", label: "Notepad" },
        { id: "rss-reader", label: "RSS" },
        { id: "scale", label: "Scale" },
        { id: "window-controls", label: "Window controls" }
    ]
    function widgetPosition(id) {
        let w = Config.rawSettings.widgets;
        return (w && w[id] && w[id].position) ? w[id].position : "default";
    }
    function setWidgetPosition(id, pos) {
        let w = {};
        let cur = Config.rawSettings.widgets;
        if (cur && typeof cur === "object") for (let k in cur) w[k] = cur[k];
        let entry = (w[id] && typeof w[id] === "object") ? w[id] : {};
        let next = {};
        for (let k in entry) next[k] = entry[k];
        next.position = pos;
        w[id] = next;
        Config.setSetting("widgets", w);
        root.posTick++;
    }

    // Tokens del preview: ids de módulos en orden (ambos engines), tolerante a
    // entradas string u objeto {id, enabled}.
    function previewTokens() {
        let out = [];
        let push = function (list) {
            if (!list) return;
            for (let i = 0; i < list.length; i++) {
                let m = list[i];
                if (Array.isArray(m)) { push(m); continue; }
                let id = (typeof m === "string") ? m : (m && m.id);
                if (!id) continue;
                if (m && typeof m === "object" && m.enabled === false) continue;
                out.push(id);
            }
        };
        if (root.bar.engine === "classic") {
            let c = root.bar.classic.modules || {};
            push(c.left); push(c.center); push(c.right);
        } else {
            let zones = root.bar.bar.zones || [];
            for (let i = 0; i < zones.length; i++) push(zones[i].modules);
        }
        return out;
    }

    // Gate: el cuerpo se crea cuando bar ya está inyectado (initial
    // property aplicada tras la creación del root). Evita bindings
    // evaluados con bar null que quedaban muertos en negro.
    readonly property var flickable: body.item ? body.item.flickable : null


    Loader {
        id: body
        anchors.fill: parent
        active: root.bar !== null
        sourceComponent: pageBody
    }

    Component {
        id: pageBody
        Item {
            anchors.fill: parent
            property alias flickable: pageFlick

            Flickable {
                id: pageFlick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: pageCol.height + bar.s(16)
                ScrollBar.vertical: ScrollBar {
                    id: vScroll
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || vScroll.hovered
                    contentItem: Rectangle {
                        radius: bar.s(2)
                        color: bar.colors.surface2
                        opacity: vScroll.active ? 1.0 : 0.45
                    }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(8)
                    y: bar.s(8)
                    width: pageFlick.width - bar.s(16)
                    spacing: bar.s(12)

                    // Título de página (GP:1007-1014)
                    Text {
                        text: "Engine"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    // Dos columnas: catálogo (izq) + ficha/acciones del engine
                    // activo (der). Todo generado del catálogo ENGINES.
                    Row {
                        width: parent.width
                        spacing: bar.s(12)

                        // ── Izquierda: catálogo + slot reservado ──────────────
                        Column {
                            width: Math.round((parent.width - bar.s(12)) * 0.60)
                            spacing: bar.s(10)
                            GridLayout {
                                width: parent.width
                                columns: 2
                                columnSpacing: bar.s(10)
                                rowSpacing: bar.s(10)
                                Repeater {
                                    model: BarLayout.ENGINES
                                    delegate: OptionCard {
                                        required property var modelData
                                            required property int index
                                        Layout.fillWidth: true
                                        bar: root.bar
                                        icon: modelData.icon
                                        label: modelData.label
                                        accentRole: modelData.accentRole
                                        active: root.bar.engine === modelData.id
                                        onActivated: root.bar.setEngine(modelData.id)
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: bar.s(64)
                                    radius: bar.s(16)
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.alpha(bar.colors.surface1, 0.7)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Next engine slot"
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                    }
                                }
                            }
                            EditLabel {
                                bar: root.bar
                                width: parent.width
                                text: "Registering a new engine (BarLayout.ENGINES + component + WindowRegistry) makes it appear here automatically."
                                font.pixelSize: bar.s(11)
                                color: bar.colors.subtext0
                                wrapMode: Text.WordWrap
                            }
                        }

                        // ── Derecha: ficha del engine activo + acciones ───────
                        Column {
                            width: parent.width - parent.children[0].width - bar.s(12)
                            spacing: bar.s(10)

                            Rectangle {
                                width: parent.width
                                radius: bar.s(16)
                                color: Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1
                                border.color: bar.colors.surface1
                                height: infoCol.height + bar.s(24)
                                Column {
                                    id: infoCol
                                    x: bar.s(14); y: bar.s(12)
                                    width: parent.width - bar.s(28)
                                    spacing: bar.s(6)
                                    EditLabel { bar: root.bar; text: "Active engine"; font.pixelSize: bar.s(12); color: bar.colors.subtext0 }
                                    Text {
                                        text: root.bar.engine === "classic" ? "ClassicBar" : "Bar"
                                        font.family: "Hack Nerd Font"
                                        font.weight: Font.Bold
                                        font.pixelSize: bar.s(18)
                                        color: bar.colors.text
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.bar.engine === "classic"
                                              ? "Left / center / right sections with autohide and fill styles."
                                              : "Islands grouped in start / center / end zones with module DnD."
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        text: "Capabilities: " + BarLayout.engineCapabilityList(BarLayout.ENGINES[root.bar.engine === "classic" ? 1 : 0])
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.bar.engine === "classic"
                                              ? "Modules: " + ((root.bar.classic.left || []).length + (root.bar.classic.center || []).length + (root.bar.classic.right || []).length)
                                                + "  ·  position: " + (root.bar.classic.position || "top")
                                              : "Modules: " + root.bar.bar.zones.reduce(function(n, z) { return n + ((z.modules || []).length); }, 0)
                                                + "  ·  zones: " + root.bar.bar.zones.length
                                                + "  ·  position: " + (root.bar.bar.position || "top")
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: bar.s(10)
                                visible: bar.engine === "classic"
                                EditorButton { bar: root.bar; icon: "󰚰"; label: "Mirror bar layout"; onActivated: root.bar.mirrorBarAction() }
                                EditorButton { bar: root.bar; label: "Classic defaults"; onActivated: root.bar.classicDefaultsAction() }
                            }
                        }
                    }

                    // Preview del engine activo: mini-barra con los módulos reales
                    Rectangle {
                        width: parent.width
                        radius: bar.s(16)
                        color: Qt.alpha(bar.colors.surface0, 0.4)
                        border.width: 1
                        border.color: bar.colors.surface1
                        height: bar.s(240)
                        Column {
                            anchors.fill: parent
                            anchors.margins: bar.s(14)
                            spacing: bar.s(10)
                            EditLabel { bar: root.bar; text: "Preview"; font.pixelSize: bar.s(12); color: bar.colors.subtext0 }
                            Rectangle {
                                width: parent.width
                                height: bar.s(44)
                                radius: bar.s(10)
                                color: Qt.alpha(bar.colors.surface1, 0.5)
                                border.width: 1
                                border.color: Qt.alpha(bar.colors.surface1, 0.9)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: bar.s(6)
                                    Repeater {
                                        model: root.previewTokens()
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: bar.s(28); height: bar.s(28); radius: bar.s(7)
                                            readonly property string role: ["mauve", "blue", "green", "peach", "pink", "teal", "yellow", "sapphire"][index % 8]
                                            color: Qt.alpha(bar.colors[role], 0.20)
                                            border.width: 1
                                            border.color: Qt.alpha(bar.colors[role], 0.75)
                                            Text {
                                                anchors.centerIn: parent
                                                text: { let m = BarLayout.getModule(modelData); return m && m.icon ? m.icon : "·"; }
                                                font.family: "Hack Nerd Font"
                                                font.pixelSize: bar.s(13)
                                                color: bar.colors[role]
                                            }
                                        }
                                    }
                                }
                            }
                            EditLabel {
                                bar: root.bar
                                width: parent.width
                                text: (root.bar.engine === "classic"
                                       ? "classic \u00b7 position " + (root.bar.classic.position || "top") + " \u00b7 thickness " + (root.bar.classic.thickness || "-") + "px"
                                       : "bar \u00b7 position " + (root.bar.bar.position || "top") + " \u00b7 zones " + (root.bar.bar.zones ? root.bar.bar.zones.length : 0))
                                font.pixelSize: bar.s(11)
                                color: bar.colors.subtext0
                            }
                        }
                    }

                    // Posiciones de los popups: matriz 3x3 espacial por widget.
                    Rectangle {
                        width: parent.width
                        radius: bar.s(16)
                        color: Qt.alpha(bar.colors.surface0, 0.4)
                        border.width: 1
                        border.color: bar.colors.surface1
                        height: posCol.height + bar.s(24)
                        Column {
                            id: posCol
                            x: bar.s(14); y: bar.s(12)
                            width: parent.width - bar.s(28)
                            spacing: bar.s(8)
                            EditLabel { bar: root.bar; text: "Popup positions"; font.pixelSize: bar.s(12); color: bar.colors.subtext0 }
                            Repeater {
                                model: root.widgetsList
                                delegate: Row {
                                    id: parentWidget
                                    required property var modelData
                                    width: posCol.width
                                    spacing: bar.s(10)
                                    Text {
                                        width: bar.s(170)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.text
                                    }
                                    GridLayout {
                                        columns: 3
                                        rowSpacing: bar.s(3); columnSpacing: bar.s(3)
                                        Repeater {
                                            model: ["top-left", "top-center", "top-right",
                                                    "center-left", "center", "center-right",
                                                    "bottom-left", "bottom-center", "bottom-right"]
                                            delegate: Rectangle {
                                                id: posCell
                                                required property var modelData
                                                readonly property bool act: root.posTick >= 0 && root.widgetPosition(parentWidget.modelData.id) === posCell.modelData
                                                width: bar.s(20); height: bar.s(20); radius: bar.s(5)
                                                color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.5)
                                                border.width: 1
                                                border.color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.9)
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setWidgetPosition(parentWidget.modelData.id, posCell.modelData) }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: bar.s(46); height: bar.s(20); radius: bar.s(5)
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property bool act: root.posTick >= 0 && root.widgetPosition(parentWidget.modelData.id) === "default"
                                        color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.3)
                                        border.width: 1
                                        border.color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.7)
                                        Text { anchors.centerIn: parent; text: "auto"; font.family: "Hack Nerd Font"; font.pixelSize: bar.s(9); color: act ? bar.colors.crust : bar.colors.subtext0 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setWidgetPosition(parentWidget.modelData.id, "default") }
                                    }
                                }
                            }
                            EditLabel { bar: root.bar; text: "auto = the widget's own layout; the rest anchor with a 20px scaled margin."; font.pixelSize: bar.s(11); color: bar.colors.subtext0 }
                        }
                    }

                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Hot switch between the zone bar and the left/center/right bar."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
