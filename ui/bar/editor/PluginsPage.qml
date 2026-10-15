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
// Below the installed cards, the page lists the plugins *available* in the
// install registry (the copy `dots` deploys) that are not installed yet: the
// Install button runs `dots plugins add <id>`, reports the output tail inline
// and rescans (the card then moves to the installed list, enabled).
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

    // Registry entries not installed yet (the Available section).
    readonly property var available: {
        PluginsCatalog.rev;
        PluginsCatalog.registryRev;
        return PluginsCatalog.availablePlugins();
    }
    readonly property bool registryMissing: {
        PluginsCatalog.registryRev;
        return PluginsCatalog.registryEntries().length === 0;
    }

    // Install flow state: one at a time; the output tail is shown inline.
    property string installingId: ""
    property string installMessage: ""
    property bool installOk: true

    function typeColor(t) {
        if (!root.bar) return "#948ae3";
        if (t === "shell") return root.bar.colors.mauve;
        if (t === "hypr")  return root.bar.colors.blue;
        if (t === "mixed") return root.bar.colors.green;
        if (t === "cli")   return root.bar.colors.yellow;
        return root.bar.colors.subtext0;
    }

    // Writes the plugin's effective toggle into the plugin's OWN settings file
    // (its state never mixes into the core settings.json), then reloads the
    // compositor for hypr-side plugins and rescans.
    function setEnabled(p, value) {
        if (!p || !p.id) return;
        let path = String(p.toggle || ("plugins." + p.id + ".enabled")).split(".");
        if (path.length < 1 || path[0] === "") return;
        let file = String(p._base || "") + "/settings.json";
        let pathJson = JSON.stringify(path);
        let v = value ? "true" : "false";
        let cmd = "f='" + file + "'; mkdir -p \"$(dirname \"$f\")\"; " +
                  "[ -f \"$f\" ] || echo '{}' > \"$f\"; " +
                  "tmp=$(mktemp \"$f\".tmp.XXXXXX) && " +
                  "jq --argjson p '" + pathJson + "' --argjson v " + v + " 'setpath($p; $v)' \"$f\" > \"$tmp\" && mv \"$tmp\" \"$f\"";
        Quickshell.execDetached(["bash", "-c", cmd]);
        if (p.type === "hypr" || p.type === "mixed") root.reloadCompositor();
        refreshTimer.restart();
    }

    // Whether the plugin's settings page is reachable: enabled + config menu
    // on (`plugins.<id>.config`, default true).
    function configShown(p) { return p ? p.config !== false : false; }
    function setConfigShown(p, value) {
        if (!p || !p.id) return;
        let obj = Object.assign({}, Config.rawSettings.plugins || {});
        let entry = Object.assign({}, obj[p.id] || {});
        entry.config = value;
        obj[p.id] = entry;
        Config.setSetting("plugins", obj);
        refreshTimer.restart();
    }

    // Install from the registry: `dots plugins add <id>` (fetch + deploy by
    // convention + enable). One at a time; on exit the catalog rescans.
    function installPlugin(r) {
        if (!r || !r.id || root.installingId !== "") return;
        root.installingId = r.id;
        root.installMessage = "";
        let id = String(r.id).replace(/'/g, "'\\''");
        let cmd = "DOTS=\"$(command -v dots || printf '%s' \"$HOME/.local/bin/dots\")\"; "
                + "exec \"$DOTS\" plugins add '" + id + "'";
        installProc.out = "";
        installProc.err = "";
        installProc.command = ["bash", "-c", cmd];
        installProc.running = false;
        installProc.running = true;
    }

    function sourceLabel(r) {
        if (!r) return "";
        return String(r.source || "") + (r.path ? "/" + r.path : "");
    }

    // Where Configure goes: the plugin's own deployed page (settings.page →
    // dynamic p_<id>, only while enabled + config menu on) or the legacy
    // fixed settings tab.
    function configureTarget(p) {
        if (p && p.settings && typeof p.settings === "object" && p.settings.page) {
            if (p.enabled !== true || !root.configShown(p)) return "";
            return "p_" + p.id;
        }
        if (p && p.settingsTab) return String(p.settingsTab);
        return "";
    }
    function reloadCompositor() { hyprReload.running = false; hyprReload.running = true; }
    Process { id: hyprReload; command: ["hyprctl", "reload"] }
    Timer { id: refreshTimer; interval: 300; onTriggered: PluginsCatalog.refresh() }

    // `dots plugins add` runner: stdout/stderr accumulated (SplitParser) and
    // the ANSI-stripped tail shown inline as the result.
    Process {
        id: installProc
        running: false
        property string out: ""
        property string err: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => installProc.out += data }
        stderr: SplitParser { splitMarker: ""; onRead: data => installProc.err += data }
        onExited: (exitCode) => {
            root.installOk = (exitCode === 0);
            let raw = (exitCode === 0 ? installProc.out : (installProc.err || installProc.out)) || "";
            let clean = raw.replace(/\u001b\[[0-9;]*m/g, "").trim();
            let lines = clean.split("\n").filter(l => l.trim() !== "");
            if (lines.length > 4) lines = lines.slice(-4);
            root.installMessage = lines.length > 0
                ? lines.join("\n")
                : (exitCode === 0 ? "Plugin installed." : "Install failed (exit " + exitCode + ").");
            installProc.out = "";
            installProc.err = "";
            root.installingId = "";
            refreshTimer.restart();
        }
    }

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
                contentHeight: pageCol.height + bar.s(Theme.gapLg)
                ScrollBar.vertical: ScrollBar {
                    id: vScroll
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || vScroll.hovered
                    contentItem: Rectangle {
                        radius: bar.s(Theme.radiusXs)
                        color: Theme.surfaceContainerHighest
                        opacity: vScroll.active ? 1.0 : 0.45
                    }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(Theme.gapSm)
                    y: bar.s(Theme.gapSm)
                    width: pageFlick.width - bar.s(Theme.gapLg)
                    spacing: bar.s(Theme.gapLg)

                    Text {
                        text: "Plugins"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }

                    RowLayout {
                        width: parent.width
                        spacing: bar.s(Theme.gapMd)
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
                            height: cardCol.implicitHeight + bar.s(Theme.gapMd) * 2
                            radius: bar.s(Theme.radiusLg)
                            color: Theme.surfaceContainerLow
                            border.width: 1
                            border.color: cardMa.containsMouse ? bar.colors.mauve : Theme.outlineVariant
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
                                anchors.leftMargin: bar.s(Theme.gapMd)
                                anchors.rightMargin: bar.s(Theme.gapMd)
                                spacing: bar.s(Theme.gapSm)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: bar.s(Theme.gapSm)
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
                                        radius: bar.s(Theme.radiusSm)
                                        color: Qt.alpha(root.typeColor(card.modelData.type), 0.15)
                                        border.width: 1
                                        border.color: root.typeColor(card.modelData.type)
                                        implicitWidth: typeText.implicitWidth + bar.s(Theme.gapMd)
                                        implicitHeight: typeText.implicitHeight + bar.s(Theme.gapXs)
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
                                    ColumnLayout {
                                        spacing: bar.s(Theme.gapXs)
                                        RowLayout {
                                            Layout.alignment: Qt.AlignRight
                                            spacing: bar.s(Theme.gapSm)
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
                                        RowLayout {
                                            Layout.alignment: Qt.AlignRight
                                            visible: !!(card.modelData.settings && card.modelData.settings.page)
                                            spacing: bar.s(Theme.gapSm)
                                            Text {
                                                text: "Config menu"
                                                font.family: "Hack Nerd Font"
                                                font.pixelSize: bar.s(11)
                                                color: root.configShown(card.modelData) ? bar.colors.text : bar.colors.subtext0
                                            }
                                            ToggleSwitch {
                                                bar: root.bar
                                                checked: root.configShown(card.modelData)
                                                onToggled: root.setConfigShown(card.modelData, !root.configShown(card.modelData))
                                            }
                                        }
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
                                    spacing: bar.s(Theme.gapSm)
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
                        text: "No plugins installed yet. Install one from the registry below, or drop a plugin folder in ~/.config/hypr/plugins-user/ and press Rescan."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    // ── Available (install registry) ─────────────────────────
                    SectionTitle {
                        visible: root.available.length > 0 || root.registryMissing
                        width: parent.width
                        bar: root.bar
                        text: "Available to install"
                    }

                    EditLabel {
                        visible: root.registryMissing
                        bar: root.bar
                        width: parent.width
                        text: "The plugin registry is not deployed yet (dots writes plugins-registry.json in the shell tree). Run `dots install` or `dots plugins available` once, then press Rescan."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.available
                        delegate: Rectangle {
                            id: availCard
                            required property var modelData
                            width: pageCol.width
                            height: availCol.implicitHeight + bar.s(Theme.gapMd) * 2
                            radius: bar.s(Theme.radiusLg)
                            color: Theme.surfaceContainerLow
                            border.width: 1
                            border.color: availMa.containsMouse ? bar.colors.blue : Theme.outlineVariant
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: availMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ColumnLayout {
                                id: availCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: bar.s(Theme.gapMd)
                                anchors.rightMargin: bar.s(Theme.gapMd)
                                spacing: bar.s(Theme.gapSm)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: bar.s(Theme.gapSm)
                                    Text {
                                        text: "󰏗"
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(16)
                                        color: bar.colors.overlay1
                                    }
                                    Text {
                                        text: availCard.modelData.name || availCard.modelData.id
                                        font.family: "Hack Nerd Font"
                                        font.weight: Font.Bold
                                        font.pixelSize: bar.s(13)
                                        color: bar.colors.text
                                    }
                                    Rectangle {
                                        radius: bar.s(Theme.radiusSm)
                                        color: Qt.alpha(bar.colors.blue, 0.12)
                                        border.width: 1
                                        border.color: Qt.alpha(bar.colors.blue, 0.6)
                                        implicitWidth: srcText.implicitWidth + bar.s(Theme.gapMd)
                                        implicitHeight: srcText.implicitHeight + bar.s(Theme.gapXs)
                                        Text {
                                            id: srcText
                                            anchors.centerIn: parent
                                            text: root.sourceLabel(availCard.modelData)
                                            font.family: "Hack Nerd Font"
                                            font.pixelSize: bar.s(9)
                                            color: bar.colors.blue
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    EditorButton {
                                        bar: root.bar
                                        compact: true
                                        icon: ""
                                        label: root.installingId === availCard.modelData.id ? "Installing…" : "Install"
                                        onActivated: root.installPlugin(availCard.modelData)
                                    }
                                }

                                EditLabel {
                                    Layout.fillWidth: true
                                    bar: root.bar
                                    text: (availCard.modelData.description || "") +
                                          (availCard.modelData.author ? "  ·  " + availCard.modelData.author : "")
                                    font.pixelSize: bar.s(11)
                                    color: bar.colors.subtext0
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    EditLabel {
                        visible: root.installMessage !== ""
                        bar: root.bar
                        width: parent.width
                        text: root.installMessage
                        font.pixelSize: bar.s(11)
                        color: root.installOk ? bar.colors.green : bar.colors.red
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
