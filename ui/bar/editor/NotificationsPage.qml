import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../core"
import "../edit"
import "../../../core"
import "../../../core/Notifications.js" as Notifications

// ═══════════════════════════════════════════════════════════════════════════
// NotificationsPage — BarEditor tab (grupo System): Do Not Disturb (DND).
//
// El estado vive en <cacheDir("dnd")>/state ("1" = silenciado, "0" = normal),
// el MISMO fichero que usa el toggle de la campana del popup de batería.
// Gate: el cuerpo se crea cuando `bar` ya está inyectado.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null
    property bool dnd: false

    // Gate: el cuerpo se crea cuando bar ya está inyectado (initial
    // property aplicada tras la creación del root). Evita bindings
    // evaluados con bar null que quedaban muertos en negro.
    readonly property var flickable: body.item ? body.item.flickable : null

    // Cache dir por widget (misma API que usa BatteryPopup).
    Caching { id: paths }

    // Estado reactivo del flag DND (FileView.text() = función en 0.3.x).
    FileView {
        id: stateFile
        path: paths.getCacheDir("dnd") + "/state"
        watchChanges: true
        onLoaded: root.readDnd()
        onFileChanged: root.readDnd()
        onLoadFailed: root.dnd = false
    }
    function readDnd() {
        try {
            root.dnd = stateFile.text().trim() === "1";
        } catch (e) {
            root.dnd = false;
        }
    }
    function setDnd(v) {
        let dir = paths.getCacheDir("dnd");
        Quickshell.execDetached(["sh", "-c", "mkdir -p '" + dir + "' && echo '" + (v ? "1" : "0") + "' > '" + dir + "/state'"]);
    }

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
                        text: "Notifications"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    // ── Layout de las notificaciones (size/shadow/posición) ──
                    Rectangle {
                        id: nLayout
                        width: parent.width
                        radius: bar.s(16)
                        color: Qt.alpha(bar.colors.surface0, 0.4)
                        border.width: 1
                        border.color: bar.colors.surface1
                        height: nCol.height + bar.s(24)
                        property int nTick: 0
                        function nCfg() { return Notifications.normalize(Config.rawSettings.notifications); }
                        function nSet(key, val) {
                            let cur = Config.rawSettings.notifications || {};
                            let next = {};
                            for (let k in cur) next[k] = cur[k];
                            next[key] = val;
                            Config.setSetting("notifications", next);
                            nLayout.nTick++;
                        }
                        Column {
                            id: nCol
                            x: bar.s(14); y: bar.s(12)
                            width: parent.width - bar.s(28)
                            spacing: bar.s(9)
                            EditLabel { bar: bar; text: "Notifications layout"; font.pixelSize: bar.s(12); color: bar.colors.subtext0 }
                            Repeater {
                                model: [
                                    { k: "width", label: "Width" },
                                    { k: "maxHeight", label: "Max height (0 = auto)" },
                                    { k: "shadowBlur", label: "Shadow blur" },
                                    { k: "shadowOffset", label: "Shadow offset" }
                                ]
                                delegate: Row {
                                    id: nRow
                                    required property var modelData
                                    width: nCol.width
                                    spacing: bar.s(8)
                                    readonly property var val: (nLayout.nTick, nLayout.nCfg()[modelData.k])
                                    Text {
                                        width: nCol.width - bar.s(150)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: nRow.modelData.label
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.text
                                    }
                                    Item {
                                        width: bar.s(130); height: bar.s(22)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            width: bar.s(20); height: bar.s(20); radius: bar.s(5)
                                            color: Qt.alpha(bar.colors.surface1, 0.5)
                                            border.width: 1; border.color: Qt.alpha(bar.colors.surface1, 0.9)
                                            Text { anchors.centerIn: parent; text: "−"; color: bar.colors.text; font.pixelSize: bar.s(12); font.family: "Hack Nerd Font" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: nLayout.nSet(nRow.modelData.k, Math.max(0, (nRow.val || 0) - 1)) }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: String(nRow.val)
                                            font.family: "Hack Nerd Font"; font.pixelSize: bar.s(12); color: bar.colors.text
                                        }
                                        Rectangle {
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: bar.s(20); height: bar.s(20); radius: bar.s(5)
                                            color: Qt.alpha(bar.colors.surface1, 0.5)
                                            border.width: 1; border.color: Qt.alpha(bar.colors.surface1, 0.9)
                                            Text { anchors.centerIn: parent; text: "+"; color: bar.colors.text; font.pixelSize: bar.s(12); font.family: "Hack Nerd Font" }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: nLayout.nSet(nRow.modelData.k, (nRow.val || 0) + 1) }
                                        }
                                    }
                                }
                            }
                            Row {
                                width: nCol.width
                                spacing: bar.s(8)
                                Text {
                                    width: nCol.width - bar.s(66)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Window shadow"
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: bar.s(12)
                                    color: bar.colors.text
                                }
                                Rectangle {
                                    id: nShadowTog
                                    width: bar.s(40); height: bar.s(20); radius: bar.s(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool on: (nLayout.nTick, nLayout.nCfg().shadow === 1)
                                    color: on ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.5)
                                    border.width: 1
                                    border.color: on ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.9)
                                    Rectangle {
                                        width: bar.s(14); height: bar.s(14); radius: bar.s(7); y: bar.s(3)
                                        x: nShadowTog.on ? parent.width - width - bar.s(3) : bar.s(3)
                                        color: nShadowTog.on ? bar.colors.crust : bar.colors.subtext0
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: nLayout.nSet("shadow", nShadowTog.on ? 0 : 1) }
                                }
                            }
                            Text {
                                text: "Position"
                                font.family: "Hack Nerd Font"
                                font.pixelSize: bar.s(12)
                                color: bar.colors.text
                            }
                            Item {
                                width: nCol.width; height: bar.s(58)
                                Repeater {
                                    model: [0, 1, 2, 3, 4, 5]
                                    delegate: Rectangle {
                                        id: nPosCell
                                        required property var modelData
                                        width: bar.s(22); height: bar.s(22); radius: bar.s(6)
                                        readonly property bool act: (nLayout.nTick, nLayout.nCfg().position === modelData)
                                        color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.5)
                                        border.width: 1
                                        border.color: act ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.9)
                                        x: (modelData % 3) * bar.s(28)
                                        y: Math.floor(modelData / 3) * bar.s(28)
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: nLayout.nSet("position", nPosCell.modelData) }
                                    }
                                }
                            }
                        }
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: "󰂛"
                        label: "Do Not Disturb"
                        checked: root.dnd
                        onToggled: root.setDnd(!root.dnd)
                    }

                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Silences notification popups. Same state as the bell toggle in the battery popup."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
