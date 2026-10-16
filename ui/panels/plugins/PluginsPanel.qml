import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../bar"
import "../../bar/edit"

// ═══════════════════════════════════════════════════════════════════════════
// PluginsPanel — the dedicated PLUGINS panel (SUPER+SHIFT+M). Material-You
// restyle: page header with live counts, a filled search field and type filter
// chips, and roomy list cards with a leading icon chip, description and per-
// plugin actions.
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

    property string selected: ""          // plugin id whose page is open ("" = list)
    property string activeMode: ""        // Main sets this from `open plugins <id>`
    property string query: ""
    property string filterType: "all"     // all | shell | hypr | mixed | cli

    // Kit context shim handed to plugin pages as `bar` (same contract the editor
    // provides: bar.s(), bar.colors, bar.gotoPage()).
    Colors { id: themeColors }
    QtObject {
        id: barShim
        function s(v) { return v; }
        property var colors: themeColors
        function gotoPage(id) { root.selected = ""; }
    }

    onActiveModeChanged: if (root.activeMode !== "" && root.activeMode !== root.selected) root.selected = root.activeMode

    // ── filtering ────────────────────────────────────────────────────────────
    function matches(p) {
        if (!p) return false;
        if (root.filterType !== "all" && String(p.type || "") !== root.filterType) return false;
        let q = root.query.trim().toLowerCase();
        if (q === "") return true;
        let hay = (String(p.name || "") + " " + String(p.id || "") + " " +
                   String(p.description || "") + " " + String(p.author || "")).toLowerCase();
        return hay.indexOf(q) !== -1;
    }
    readonly property var filtered: (root.plugins || []).filter(function (p) { return root.matches(p); })
    readonly property int enabledCount: (root.plugins || []).filter(function (p) { return p && p.enabled === true; }).length
    readonly property var typeList: {
        let seen = {}; let out = [];
        let l = root.plugins || [];
        for (let i = 0; i < l.length; i++) {
            let t = String((l[i] || {}).type || "");
            if (t !== "" && !seen[t]) { seen[t] = true; out.push(t); }
        }
        out.sort();
        return out;
    }

    function pluginById(id) {
        let l = root.plugins;
        for (let i = 0; i < l.length; i++) if (l[i] && l[i].id === id) return l[i];
        return null;
    }

    // Optimistic enable state: the toggle must reflect the click IMMEDIATELY
    // and be correct regardless of how long the async rescan takes (the scan
    // re-reads the plugin's settings file, which the write may still be
    // flushing → the old fixed-delay timer read a stale value and the toggle
    // appeared to need several clicks). The override is dropped as soon as the
    // catalog confirms the value.
    property var _opt: ({})
    function effectiveEnabled(p) {
        if (!p || !p.id) return false;
        return (_opt[p.id] !== undefined) ? (_opt[p.id] === true) : (p.enabled === true);
    }
    function _reconcile() {
        let next = {}; let changed = false;
        for (let id in _opt) {
            let p = root.pluginById(id);
            if (p && (p.enabled === true) === (_opt[id] === true)) { changed = true; continue; }
            next[id] = _opt[id];
        }
        if (changed) _opt = next;
    }
    Connections {
        target: PluginsCatalog
        function onRevChanged() { root._reconcile(); }
    }

    // Enable/disable writes the plugin's OWN settings file (never settings.json).
    // The write is serialized and only THEN triggers the rescan, so the catalog
    // never reads a half-written file.
    Process {
        id: writer
        property string pendingCmd: ""
        property var pendingCb: null
        property string queuedCmd: ""
        property var queuedCb: null
        function exec(cmd, cb) {
            if (running) { queuedCmd = cmd; queuedCb = cb; return; }
            pendingCmd = cmd; pendingCb = cb;
            command = ["bash", "-c", cmd];
            running = true;
        }
        onExited: {
            let f = pendingCb; pendingCb = null; if (f) f();
            if (queuedCmd !== "") { let c = queuedCmd, g = queuedCb; queuedCmd = ""; queuedCb = null; exec(c, g); }
        }
    }
    Process { id: hyprctlReload; command: ["hyprctl", "reload"] }

    function setEnabled(p, value) {
        if (!p || !p.id) return;
        // Optimistic: reflect the click now.
        let o = Object.assign({}, _opt); o[p.id] = value === true; _opt = o;
        let path = String(p.toggle || ((p.scope || p.id) + ".enabled")).split(".");
        let file = String(p._base || "") + "/settings.json";
        let pathJson = JSON.stringify(path);
        let v = value ? "true" : "false";
        let cmd = "f='" + file + "'; mkdir -p \"$(dirname \"$f\")\"; " +
                  "[ -s \"$f\" ] || echo '{}' > \"$f\"; " +
                  "tmp=$(mktemp \"$f\".tmp.XXXXXX) && " +
                  "jq --argjson p '" + pathJson + "' --argjson v " + v + " 'setpath($p; $v)' \"$f\" > \"$tmp\" && mv \"$tmp\" \"$f\"";
        writer.exec(cmd, function () {
            if (p.type === "hypr" || p.type === "mixed") hyprctlReload.running = true;
            PluginsCatalog.refresh();
        });
    }

    function typeColor(t) {
        if (t === "shell") return barShim.colors.mauve;
        if (t === "hypr")  return barShim.colors.blue;
        if (t === "mixed") return barShim.colors.green;
        if (t === "cli")   return barShim.colors.yellow;
        return barShim.colors.subtext0;
    }
    function openPanel(p) {
        let ps = (p && p.provides ? p.provides.panels : null) || {};
        let k = Object.keys(ps)[0];
        if (k) Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", k]);
    }
    function hasPanel(p) {
        let ps = (p && p.provides ? p.provides.panels : null) || {};
        return Object.keys(ps).length > 0;
    }

    // ══ LIST ═══════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.gapLg
        spacing: Theme.gapMd
        visible: root.selected === ""

        // ── header ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapMd

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 44; height: 44; radius: Theme.radiusMd
                color: Qt.alpha(barShim.colors.mauve, 0.15)
                Text {
                    anchors.centerIn: parent; text: "󰏗"
                    font.family: "Hack Nerd Font"; font.pixelSize: 20
                    color: barShim.colors.mauve
                }
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: "Plugins"
                    font.family: "Hack Nerd Font"; font.weight: Font.Black; font.pixelSize: 24
                    color: barShim.colors.text
                }
                Text {
                    text: root.plugins.length + " installed · " + root.enabledCount + " enabled"
                    font.family: "Hack Nerd Font"; font.pixelSize: 11
                    color: barShim.colors.subtext0
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ── search field (MD3 filled) ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radiusFull
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: searchInput.activeFocus ? barShim.colors.mauve : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.gapMd
                anchors.rightMargin: Theme.gapSm
                spacing: Theme.gapSm

                Text {
                    text: "󰍉"
                    font.family: "Hack Nerd Font"; font.pixelSize: 16
                    color: barShim.colors.subtext0
                }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    clip: true
                    color: barShim.colors.text
                    font.family: "Hack Nerd Font"; font.pixelSize: 13
                    selectByMouse: true
                    selectionColor: Qt.alpha(barShim.colors.mauve, 0.35)
                    selectedTextColor: barShim.colors.text
                    onTextChanged: root.query = text

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search plugins…"
                        font.family: "Hack Nerd Font"; font.pixelSize: 13
                        color: Qt.alpha(barShim.colors.subtext0, 0.8)
                    }
                    Keys.onEscapePressed: { text = ""; root.query = ""; focus = false; }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    visible: searchInput.text !== ""
                    width: 24; height: 24; radius: Theme.radiusFull
                    color: clearMa.containsMouse ? Theme.stateLayer(barShim.colors.text, Theme.stateHover) : "transparent"
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: "Hack Nerd Font"; font.pixelSize: 13; color: barShim.colors.subtext0 }
                    MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { searchInput.text = ""; root.query = ""; } }
                }
            }
        }

        // ── type filter chips ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            Repeater {
                model: [["all", "All"]].concat(root.typeList.map(function (t) { return [t, t.charAt(0).toUpperCase() + t.slice(1)]; }))
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: root.filterType === modelData[0]
                    readonly property color accent: modelData[0] === "all" ? barShim.colors.mauve : root.typeColor(modelData[0])
                    radius: Theme.radiusFull
                    color: on ? Theme.stateLayer(accent, Theme.statePress) : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: on ? accent : Theme.outlineVariant
                    implicitWidth: chipText.implicitWidth + Theme.gapLg * 2
                    implicitHeight: 30
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: modelData[1]
                        font.family: "Hack Nerd Font"; font.pixelSize: 12
                        font.weight: on ? Font.Bold : Font.Normal
                        color: on ? barShim.colors.text : barShim.colors.subtext0
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.filterType = modelData[0]
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ── list ────────────────────────────────────────────────────────────
        Flickable {
            id: listFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: listCol.height + Theme.gapLg
            ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }

            Column {
                id: listCol
                width: listFlick.width - Theme.gapMd
                spacing: Theme.gapSm

                Repeater {
                    model: root.filtered
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        width: listCol.width
                        implicitHeight: 96
                        radius: Theme.radiusLg
                        color: cardHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                        border.width: 1
                        border.color: cardHover.hovered ? Qt.alpha(root.typeColor(card.modelData.type), 0.7) : Theme.outlineVariant
                        Behavior on color { ColorAnimation { duration: Theme.durShort } }

                        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.gapMd
                            spacing: Theme.gapMd

                            // leading type icon chip
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 42; height: 42; radius: Theme.radiusMd
                                color: Qt.alpha(root.typeColor(card.modelData.type), 0.15)
                                Text {
                                    anchors.centerIn: parent; text: "󰏗"
                                    font.family: "Hack Nerd Font"; font.pixelSize: 18
                                    color: root.typeColor(card.modelData.type)
                                }
                            }

                            // middle: name / description / actions
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: Theme.gapSm
                                    Text {
                                        text: card.modelData.name || card.modelData.id
                                        font.family: "Hack Nerd Font"; font.weight: Font.Bold; font.pixelSize: 14
                                        color: barShim.colors.text
                                    }
                                    Text {
                                        text: "v" + (card.modelData.version || "?")
                                        font.family: "Hack Nerd Font"; font.pixelSize: 10
                                        color: barShim.colors.subtext0
                                    }
                                    Rectangle {
                                        radius: Theme.radiusSm
                                        color: Qt.alpha(root.typeColor(card.modelData.type), 0.15)
                                        border.width: 1; border.color: root.typeColor(card.modelData.type)
                                        implicitWidth: typeTxt.implicitWidth + Theme.gapMd
                                        implicitHeight: typeTxt.implicitHeight + Theme.gapXs
                                        Text {
                                            id: typeTxt; anchors.centerIn: parent
                                            text: card.modelData.type || "plugin"
                                            font.family: "Hack Nerd Font"; font.pixelSize: 9
                                            color: root.typeColor(card.modelData.type)
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                EditLabel {
                                    Layout.fillWidth: true
                                    text: (card.modelData.description || "No description")
                                    font.pixelSize: 11; color: barShim.colors.subtext0
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: Theme.gapSm
                                    EditorButton { bar: barShim; compact: true; icon: "󰒓"; label: "Configure"; visible: !!(card.modelData.settings && card.modelData.settings.page); onActivated: root.selected = card.modelData.id }
                                    EditorButton { bar: barShim; compact: true; icon: "󰖯"; label: "Open"; visible: root.hasPanel(card.modelData); onActivated: root.openPanel(card.modelData) }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            // trailing: enable state + toggle
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Theme.gapXs
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.effectiveEnabled(card.modelData) ? "Enabled" : "Disabled"
                                    font.family: "Hack Nerd Font"; font.weight: Font.Bold; font.pixelSize: 10
                                    color: root.effectiveEnabled(card.modelData) ? barShim.colors.mauve : barShim.colors.subtext0
                                }
                                ToggleSwitch {
                                    Layout.alignment: Qt.AlignHCenter
                                    bar: barShim
                                    checked: root.effectiveEnabled(card.modelData)
                                    onToggled: root.setEnabled(card.modelData, !root.effectiveEnabled(card.modelData))
                                }
                            }
                        }
                    }
                }

                // empty state
                Item {
                    width: listCol.width
                    height: 160
                    visible: root.filtered.length === 0
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.gapSm
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍉"; font.family: "Hack Nerd Font"; font.pixelSize: 34
                            color: Qt.alpha(barShim.colors.subtext0, 0.6)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.plugins.length === 0) ? "No plugins installed." : "No plugins match your search."
                            font.family: "Hack Nerd Font"; font.pixelSize: 12
                            color: barShim.colors.subtext0
                        }
                    }
                }
            }
        }
    }

    // ══ PLUGIN PAGE (own settings page, hosted here) ═══════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.gapLg
        spacing: Theme.gapMd
        visible: root.selected !== ""

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 34; height: 34; radius: Theme.radiusFull
                color: backMa.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                border.width: 1; border.color: Theme.outlineVariant
                Text { anchors.centerIn: parent; text: "←"; font.family: "Hack Nerd Font"; font.pixelSize: 15; color: barShim.colors.text }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = "" }
            }
            Text {
                id: pageName
                text: { let p = root.pluginById(root.selected); return p ? (p.name || p.id) : ""; }
                font.family: "Hack Nerd Font"; font.weight: Font.Black; font.pixelSize: 18
                color: barShim.colors.text
            }
            Rectangle {
                visible: { let p = root.pluginById(root.selected); return !!(p && p.type); }
                radius: Theme.radiusSm
                color: Qt.alpha(root.typeColor((root.pluginById(root.selected) || {}).type), 0.15)
                border.width: 1; border.color: root.typeColor((root.pluginById(root.selected) || {}).type)
                implicitWidth: ptxt.implicitWidth + Theme.gapMd
                implicitHeight: ptxt.implicitHeight + Theme.gapXs
                Text {
                    id: ptxt; anchors.centerIn: parent
                    text: (root.pluginById(root.selected) || {}).type || ""
                    font.family: "Hack Nerd Font"; font.pixelSize: 9
                    color: root.typeColor((root.pluginById(root.selected) || {}).type)
                }
            }
            Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outlineVariant }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
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
