import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../edit"
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// PluginsPage — BarEditor tab (Plugins group): the installed-plugin manager.
//
// One card per plugin discovered by PluginsCatalog, from the registry folders
// (~/.config/hypr/plugins managed by dots + ~/.config/hypr/plugins-user, the
// user dir wins on id collisions): identity, type badge, description, an
// enable/disable switch and a Configure shortcut that jumps to the plugin's
// own settings page (plugin.json → settings.page → dynamic p_<id>; the
// legacy settingsTab key is still honored).
//
// The switch writes the plugin's effective toggle in settings.json
// (plugin.json → toggle, default plugins.<id>.enabled). Shell plugins react
// live through the settings watcher; hypr plugins need a compositor config
// reload, which is triggered with `hyprctl reload` after the write. The
// catalog rescans shortly after so the card reflects the new state.
//
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors,
// bar.gotoPage()).
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null

    readonly property var plugins: {
        PluginsCatalog.rev; // re-evaluate after every scan
        return PluginsCatalog.plugins || [];
    }

    function typeColor(t) {
        if (!root.bar) return "#948ae3";
        if (t === "shell") return root.bar.colors.mauve;
        if (t === "hypr")  return root.bar.colors.blue;
        if (t === "mixed") return root.bar.colors.green;
        if (t === "cli")   return root.bar.colors.yellow;
        return root.bar.colors.subtext0;
    }

    // Writes the plugin's effective toggle path (plugins.<id>.enabled by
    // default) and reloads the compositor for hypr-side plugins.
    function setEnabled(p, value) {
        let path = String(p.toggle || ("plugins." + p.id + ".enabled")).split(".");
        if (path.length < 2 || path[0] === "") return;
        let top = path[0];
        let obj = Object.assign({}, Config.rawSettings[top] || {});
        let cur = obj;
        for (let i = 1; i < path.length - 1; i++) {
            cur[path[i]] = Object.assign({}, cur[path[i]] || {});
            cur = cur[path[i]];
        }
        cur[path[path.length - 1]] = value;
        Config.setSetting(top, obj);
        if (p.type === "hypr" || p.type === "mixed") root.reloadCompositor();
        refreshTimer.restart();
    }

    // Where Configure goes: the plugin's own deployed page (settings.page →
    // dynamic p_<id>) or the legacy fixed settings tab.
    function configureTarget(p) {
        if (p && p.settings && typeof p.settings === "object" && p.settings.page)
            return "p_" + p.id;
        if (p && p.settingsTab) return String(p.settingsTab);
        return "";
    }
    function reloadCompositor() { hyprReload.running = false; hyprReload.running = true; }
    Process { id: hyprReload; command: ["hyprctl", "reload"] }
    Timer { id: refreshTimer; interval: 300; onTriggered: PluginsCatalog.refresh() }

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

                    Text {
                        text: "Plugins"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    RowLayout {
                        width: parent.width
                        spacing: bar.s(10)
                        EditLabel {
                            bar: root.bar
                            Layout.fillWidth: true
                            text: "Features installed as plugins, discovered from ~/.config/hypr/plugins (managed by dots) and ~/.config/hypr/plugins-user (yours; wins on collisions). Enable one and its keybinds, scripts and UI plug in live."
                            font.pixelSize: bar.s(11)
                            color: bar.colors.subtext0
                            wrapMode: Text.WordWrap
                        }
                        EditorButton {
                            bar: root.bar
                            compact: true
                            icon: ""
                            label: "Rescan"
                            onActivated: PluginsCatalog.refresh()
                        }
                    }

                    Repeater {
                        model: root.plugins
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            width: pageCol.width
                            height: cardCol.implicitHeight + bar.s(24)
                            radius: bar.s(18)
                            color: Qt.alpha(bar.colors.surface0, 0.4)
                            border.width: 1
                            border.color: cardMa.containsMouse ? bar.colors.mauve : bar.colors.surface1
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ColumnLayout {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: bar.s(14)
                                anchors.rightMargin: bar.s(14)
                                spacing: bar.s(6)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: bar.s(8)
                                    Text {
                                        text: "󰏗"
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(16)
                                        color: root.typeColor(card.modelData.type)
                                    }
                                    Text {
                                        text: card.modelData.name || card.modelData.id
                                        font.family: "Hack Nerd Font"
                                        font.weight: Font.Bold
                                        font.pixelSize: bar.s(13)
                                        color: bar.colors.text
                                    }
                                    Text {
                                        text: "v" + (card.modelData.version || "?")
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(10)
                                        color: bar.colors.subtext0
                                    }
                                    Rectangle {
                                        radius: bar.s(6)
                                        color: Qt.alpha(root.typeColor(card.modelData.type), 0.15)
                                        border.width: 1
                                        border.color: root.typeColor(card.modelData.type)
                                        implicitWidth: typeText.implicitWidth + bar.s(12)
                                        implicitHeight: typeText.implicitHeight + bar.s(4)
                                        Text {
                                            id: typeText
                                            anchors.centerIn: parent
                                            text: card.modelData.type || "plugin"
                                            font.family: "Hack Nerd Font"
                                            font.pixelSize: bar.s(9)
                                            color: root.typeColor(card.modelData.type)
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: card.modelData.enabled ? "Enabled" : "Disabled"
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(11)
                                        font.weight: Font.Bold
                                        color: card.modelData.enabled ? bar.colors.mauve : bar.colors.subtext0
                                    }
                                    ToggleSwitch {
                                        bar: root.bar
                                        checked: card.modelData.enabled === true
                                        onToggled: root.setEnabled(card.modelData, !card.modelData.enabled)
                                    }
                                }

                                EditLabel {
                                    Layout.fillWidth: true
                                    bar: root.bar
                                    text: (card.modelData.description || "") +
                                          (card.modelData.author ? "  ·  " + card.modelData.author : "")
                                    font.pixelSize: bar.s(11)
                                    color: bar.colors.subtext0
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: bar.s(8)
                                    EditorButton {
                                        bar: root.bar
                                        compact: true
                                        icon: "󰒓"
                                        label: "Configure"
                                        visible: root.configureTarget(card.modelData) !== ""
                                        onActivated: {
                                            let target = root.configureTarget(card.modelData);
                                            if (target !== "" && root.bar.gotoPage)
                                                root.bar.gotoPage(target);
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: card.modelData._base || ""
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(9)
                                        color: Qt.alpha(bar.colors.subtext0, 0.7)
                                    }
                                }
                            }
                        }
                    }

                    EditLabel {
                        visible: root.plugins.length === 0
                        bar: root.bar
                        width: parent.width
                        text: "No plugins installed yet. Drop a plugin folder in ~/.config/hypr/plugins-user/ and press Rescan."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
