import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../bar"
import "../../bar/edit"

// ═══════════════════════════════════════════════════════════════════════════
// PluginsPanel — the dedicated PLUGINS panel (separate from the core config
// panel). It is the ONLY plugin surface: the manager (list + enable/disable +
// compat) and each plugin's OWN settings page, rendered inside this panel.
//
// Autonomy: it never touches the core settings.json. Enabling/disabling writes
// the plugin's OWN settings file (~/.config/hypr/plugins/<id>/settings.json);
// the core only DISCOVERS plugins (PluginsCatalog scan) and mounts them.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root

    readonly property var plugins: {
        PluginsCatalog.rev;
        return PluginsCatalog.plugins || [];
    }

    // Kit context shim handed to plugin pages as `bar` (the same contract the
    // editor provides: bar.s(), bar.colors, bar.gotoPage()).
    Colors { id: themeColors }
    QtObject {
        id: barShim
        function s(v) { return v; }
        property var colors: themeColors
        function gotoPage(id) { root.selected = ""; }
    }

    property string selected: ""          // plugin id whose page is open ("" = list)
    property string activeMode: ""        // Main sets this from `open plugins <id>`
    onActiveModeChanged: if (root.activeMode !== "" && root.activeMode !== root.selected) root.selected = root.activeMode

    function pluginById(id) {
        let l = root.plugins;
        for (let i = 0; i < l.length; i++) if (l[i] && l[i].id === id) return l[i];
        return null;
    }

    // Enable/disable writes the plugin's OWN settings file (never settings.json).
    function setEnabled(p, value) {
        if (!p || !p.id) return;
        let path = String(p.toggle || (p.id + ".enabled")).split(".");
        let file = String(p._base || "") + "/settings.json";
        let pathJson = JSON.stringify(path);
        let v = value ? "true" : "false";
        let cmd = "f='" + file + "'; mkdir -p \"$(dirname \"$f\")\"; " +
                  "[ -s \"$f\" ] || echo '{}' > \"$f\"; " +
                  "tmp=$(mktemp \"$f\".tmp.XXXXXX) && " +
                  "jq --argjson p '" + pathJson + "' --argjson v " + v + " 'setpath($p; $v)' \"$f\" > \"$tmp\" && mv \"$tmp\" \"$f\"";
        Quickshell.execDetached(["bash", "-c", cmd]);
        if (p.type === "hypr" || p.type === "mixed") hyprctlReload.running = true;
        rescanTimer.restart();
    }
    Process { id: hyprctlReload; command: ["hyprctl", "reload"] }
    Timer { id: rescanTimer; interval: 300; onTriggered: PluginsCatalog.refresh() }

    function typeColor(t) {
        if (t === "shell") return barShim.colors.mauve;
        if (t === "hypr")  return barShim.colors.blue;
        if (t === "mixed") return barShim.colors.green;
        if (t === "cli")   return barShim.colors.yellow;
        return barShim.colors.subtext0;
    }

    // ── list ───────────────────────────────────────────────────────────────
    Flickable {
        id: listFlick
        anchors.fill: parent
        visible: root.selected === ""
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: listCol.height + Theme.gapLg
        ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }

        Column {
            id: listCol
            x: Theme.gapSm; y: Theme.gapSm
            width: listFlick.width - Theme.gapLg
            spacing: Theme.gapSm

            Text { text: "Plugins"; font.family: "Hack Nerd Font"; font.weight: Font.Black; font.pixelSize: 24; color: barShim.colors.text }
            EditLabel {
                width: parent.width; text: "Installed plugins (discovered, never written by the core). Enable/disable writes each plugin's own settings file."
                font.pixelSize: 11; color: barShim.colors.subtext0; wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.plugins
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: listCol.width
                    height: cardCol.implicitHeight + Theme.gapXl
                    radius: Theme.radiusLg
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: cardMa.containsMouse ? barShim.colors.mauve : Theme.outlineVariant

                    MouseArea { id: cardMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                    ColumnLayout {
                        id: cardCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.gapMd
                        spacing: Theme.gapXs

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.gapSm
                            Text { text: "󰏗"; font.family: "Hack Nerd Font"; font.pixelSize: 16; color: root.typeColor(card.modelData.type) }
                            Text { text: card.modelData.name || card.modelData.id; font.family: "Hack Nerd Font"; font.weight: Font.Bold; font.pixelSize: 13; color: barShim.colors.text }
                            Text { text: "v" + (card.modelData.version || "?"); font.family: "Hack Nerd Font"; font.pixelSize: 10; color: barShim.colors.subtext0 }
                            Rectangle {
                                radius: Theme.radiusSm; color: Qt.alpha(root.typeColor(card.modelData.type), 0.15)
                                border.width: 1; border.color: root.typeColor(card.modelData.type)
                                implicitWidth: tt.implicitWidth + Theme.gapMd; implicitHeight: tt.implicitHeight + Theme.gapXs
                                Text { id: tt; anchors.centerIn: parent; text: card.modelData.type || "plugin"; font.family: "Hack Nerd Font"; font.pixelSize: 9; color: root.typeColor(card.modelData.type) }
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: card.modelData.enabled ? "Enabled" : "Disabled"; font.family: "Hack Nerd Font"; font.weight: Font.Bold; font.pixelSize: 11; color: card.modelData.enabled ? barShim.colors.mauve : barShim.colors.subtext0 }
                            ToggleSwitch { bar: barShim; checked: card.modelData.enabled === true; onToggled: root.setEnabled(card.modelData, !card.modelData.enabled) }
                        }
                        EditLabel {
                            Layout.fillWidth: true
                            text: (card.modelData.description || "") + (card.modelData.author ? "  ·  " + card.modelData.author : "")
                            font.pixelSize: 11; color: barShim.colors.subtext0; wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.gapSm
                            EditorButton { bar: barShim; compact: true; icon: "󰒓"; label: "Configure"; visible: !!(card.modelData.settings && card.modelData.settings.page); onActivated: root.selected = card.modelData.id }
                            // Plugins that ship a panel/popup get a direct opener.
                            EditorButton {
                                bar: barShim; compact: true; icon: "󰖯"; label: "Open"
                                visible: { let ps = (card.modelData.provides || {}).panels; return !!ps && Object.keys(ps).length > 0; }
                                onActivated: {
                                    let ps = (card.modelData.provides || {}).panels || {};
                                    let k = Object.keys(ps)[0];
                                    if (k) Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", k]);
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: card.modelData._base || ""; font.family: "Hack Nerd Font"; font.pixelSize: 9; color: Qt.alpha(barShim.colors.subtext0, 0.7) }
                        }
                    }
                }
            }
            EditLabel { visible: root.plugins.length === 0; width: parent.width; text: "No plugins installed."; font.pixelSize: 11; color: barShim.colors.subtext0 }
        }
    }

    // ── plugin page (own settings page, hosted here) ─────────────────────────
    Item {
        anchors.fill: parent
        visible: root.selected !== ""

        RowLayout {
            id: pageBar
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 36
            EditorButton { bar: barShim; compact: true; icon: "←"; label: "Plugins"; onActivated: root.selected = "" }
            Item { Layout.fillWidth: true }
            Text {
                text: {
                    let p = root.pluginById(root.selected);
                    return p ? (p.name || p.id) : "";
                }
                font.family: "Hack Nerd Font"; font.weight: Font.Bold; font.pixelSize: 12; color: barShim.colors.text
            }
        }

        Loader {
            id: pageLoader
            anchors.top: pageBar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            active: root.selected !== ""
            source: {
                if (!active || root.selected === "") return "";
                let p = root.pluginById(root.selected);
                if (!p || !p.settings || !p.settings.page) return "";
                let page = String(p.settings.page).replace(/^\.\//, "");
                if (PluginsCatalog.isManaged(p)) return "../../plugins/" + p.id + "/" + page;
                return PluginsCatalog.uiUrl(p, page);
            }
            onLoaded: {
                if (item) {
                    item.bar = barShim;
                    if (item.host !== undefined) item.host = HostApi.forPlugin(root.pluginById(root.selected));
                }
            }
        }
    }
}
