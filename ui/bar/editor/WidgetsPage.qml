import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"
import "../../../core"
import "../../../core/Personalization.js" as Personalization

// ═══════════════════════════════════════════════════════════════════════════
// WidgetsPage — per-widget options editor. Every control reads/writes the
// option tables exposed by core/Personalization.js (settings.json sections:
// "network", "volume", "battery", ...). Changes apply the next time the
// widget opens (Main.getLayout reads settings on each open).
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent
    property var bar: null

    readonly property var sections: [
        { id: "network", label: "Wifi / Bluetooth" },
        { id: "volume", label: "Sound" },
        { id: "battery", label: "Battery" },
        { id: "system-monitor", label: "System monitor" },
        { id: "calendar", label: "Calendar" },
        { id: "clipboard", label: "Clipboard" },
        { id: "quicknotes", label: "Notepad" },
        { id: "rss-reader", label: "RSS reader" },
        { id: "file-search", label: "File search" },
        { id: "scale", label: "Scale picker" },
        { id: "window-controls", label: "Window controls" },
        { id: "lock", label: "Lock screen" },
        { id: "updater", label: "Updater" },
        { id: "idle", label: "Idle" },
        { id: "widgets", label: "Desktop widgets" }
    ]
    property int tick: 0

    function cfg(id) { return Personalization.normalize(id, Config.rawSettings[id]); }
    function setOpt(id, key, val) {
        Config.setSetting(id, Personalization.setOption(id, Config.rawSettings[id], key, val));
        root.tick++;
    }
    function pretty(k) {
        return k.replace(/([A-Z])/g, " $1").replace(/^./, function (c) { return c.toUpperCase(); });
    }

    Loader { id: body; anchors.fill: parent; active: root.bar !== null; sourceComponent: pageBody }

    Component {
        id: pageBody
        Item {
            anchors.fill: parent

            Flickable {
                id: pageFlick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: pageCol.height + bar.s(16)
                ScrollBar.vertical: ScrollBar {
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: bar.s(2); color: bar.colors.surface2; opacity: parent.active ? 1 : 0.45 }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(8); y: bar.s(8)
                    width: pageFlick.width - bar.s(16)
                    spacing: bar.s(12)

                    Text {
                        text: "Widgets"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Every popup and panel option exposed by core/Personalization.js. Changes apply the next time the widget opens."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        Repeater {
                            model: root.sections
                            delegate: Rectangle {
                                id: secCard
                                required property var modelData
                                Layout.fillWidth: true
                                radius: bar.s(16)
                                color: Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1
                                border.color: bar.colors.surface1
                                height: secCol.height + bar.s(24)
                                Column {
                                    id: secCol
                                    x: bar.s(14); y: bar.s(12)
                                    width: parent.width - bar.s(28)
                                    spacing: bar.s(6)
                                    Text {
                                        text: secCard.modelData.label
                                        font.family: "Hack Nerd Font"
                                        font.weight: Font.Bold
                                        font.pixelSize: bar.s(14)
                                        color: bar.colors.text
                                    }
                                    Repeater {
                                        model: (root.tick, Object.keys(root.cfg(secCard.modelData.id)))
                                        delegate: Row {
                                            id: optRow
                                            required property var modelData
                                            width: secCol.width
                                            spacing: bar.s(8)
                                            readonly property var val: (root.tick, root.cfg(secCard.modelData.id)[modelData])
                                            readonly property bool isBool: typeof val === "boolean"
                                            Text {
                                                width: secCol.width - bar.s(120)
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.pretty(optRow.modelData)
                                                font.family: "Hack Nerd Font"
                                                font.pixelSize: bar.s(12)
                                                color: bar.colors.subtext0
                                                elide: Text.ElideRight
                                            }
                                            Rectangle {
                                                visible: optRow.isBool
                                                width: bar.s(40); height: bar.s(20); radius: bar.s(10)
                                                color: optRow.val ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.5)
                                                border.width: 1
                                                border.color: optRow.val ? bar.colors.mauve : Qt.alpha(bar.colors.surface1, 0.9)
                                                Rectangle {
                                                    width: bar.s(14); height: bar.s(14); radius: bar.s(7)
                                                    y: bar.s(3)
                                                    x: optRow.val ? parent.width - width - bar.s(3) : bar.s(3)
                                                    color: optRow.val ? bar.colors.crust : bar.colors.subtext0
                                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setOpt(secCard.modelData.id, optRow.modelData, !optRow.val)
                                                }
                                            }
                                            Item {
                                                visible: !optRow.isBool
                                                width: bar.s(84); height: bar.s(22)
                                                anchors.verticalCenter: parent.verticalCenter
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                                    width: bar.s(20); height: bar.s(20); radius: bar.s(5)
                                                    color: Qt.alpha(bar.colors.surface1, 0.5)
                                                    border.width: 1; border.color: Qt.alpha(bar.colors.surface1, 0.9)
                                                    Text { anchors.centerIn: parent; text: "−"; color: bar.colors.text; font.pixelSize: bar.s(12); font.family: "Hack Nerd Font" }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.setOpt(secCard.modelData.id, optRow.modelData, Math.max(0, (optRow.val || 0) - 1))
                                                    }
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(optRow.val)
                                                    font.family: "Hack Nerd Font"; font.pixelSize: bar.s(12); color: bar.colors.text
                                                }
                                                Rectangle {
                                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                                    width: bar.s(20); height: bar.s(20); radius: bar.s(5)
                                                    color: Qt.alpha(bar.colors.surface1, 0.5)
                                                    border.width: 1; border.color: Qt.alpha(bar.colors.surface1, 0.9)
                                                    Text { anchors.centerIn: parent; text: "+"; color: bar.colors.text; font.pixelSize: bar.s(12); font.family: "Hack Nerd Font" }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.setOpt(secCard.modelData.id, optRow.modelData, (optRow.val || 0) + 1)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
