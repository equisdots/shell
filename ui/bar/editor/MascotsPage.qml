import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../edit"
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// MascotsPage — BarEditor tab (Theme group): the mascot island overlay.
//
// The widget itself lives in ui/Mascots.qml (a click-through overlay): a small
// island at the top that morphs into a dock while the app launcher is open,
// with chibi mascots that follow the cursor and react to window open/close
// events. This page edits the settings.json "mascots" section.
//
// Contract: receives the BarEditor root as `bar` (bar.s(), bar.colors).
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: root
    anchors.fill: parent

    property var bar: null

    // Same defaults Nyx's front/MascotsOverlay.qml falls back to.
    property bool mEnabled: false
    property real mSize: 1.0
    property string mSpecies: "flame"
    property int mCount: 3
    property string mPosition: "top-center"
    property string mAppearance: "island"
    property real mNotchWidth: 260
    property real mNotchHeight: 0
    property real mNotchOffset: 0
    property bool mNotchReserve: true
    property string mDockStyle: "floating"
    property string mDockSize: "large"
    property int mDockColumns: 5
    property int mDockRows: 2
    property bool mDockHero: true
    property bool mDockQuick: true
    property bool mDockSearch: true
    property string mWatcherFormat: "24"
    property bool mWatcherSeconds: true
    property real mWatcherSpeed: 1.0
    property bool mWatcherMoods: true
    property bool mWatcherEye: false
    property string mProfileName: ""

    // ── profiles ───────────────────────────────────────────────────────────
    readonly property var profilesObj: {
        Config.rev;
        let m = Config.rawSettings.mascots || {};
        return (m.profiles && typeof m.profiles === "object") ? m.profiles : {};
    }
    readonly property var profileNames: Object.keys(root.profilesObj)
    function currentBlock() {
        let m = Config.rawSettings.mascots || {};
        let b = {};
        ["enabled", "species", "count", "size", "position", "appearance",
         "notchWidth", "notchHeight", "notchOffset", "notchReserve"].forEach(function (k) {
            if (m[k] !== undefined) b[k] = m[k];
        });
        if (m.dock) b.dock = m.dock;
        if (m.watcher) b.watcher = m.watcher;
        return b;
    }
    function saveProfile(name) {
        if (!name) return;
        let m = Object.assign({}, Config.rawSettings.mascots || {});
        let p = Object.assign({}, root.profilesObj);
        p[name] = root.currentBlock();
        m.profiles = p;
        Config.setSetting("mascots", m);
    }
    function loadProfile(name) {
        let m = Object.assign({}, Config.rawSettings.mascots || {});
        let block = root.profilesObj[name];
        if (!block) return;
        let next = Object.assign({}, block);
        next.profiles = m.profiles;
        Config.setSetting("mascots", next);
        root.syncFromConfig();
    }
    function deleteProfile(name) {
        let m = Object.assign({}, Config.rawSettings.mascots || {});
        let p = Object.assign({}, root.profilesObj);
        delete p[name];
        m.profiles = p;
        Config.setSetting("mascots", m);
    }

    readonly property var flickable: body.item ? body.item.flickable : null

    function syncFromConfig() {
        let s = (Config.rawSettings.mascots && typeof Config.rawSettings.mascots === "object")
                ? Config.rawSettings.mascots : {};
        root.mEnabled = s.enabled === true;
        root.mSize = s.size !== undefined ? s.size : 1.0;
        let sp = (typeof s.species === "string") ? s.species : "flame";
        root.mSpecies = (sp === "classic") ? "flame" : sp;
        root.mCount = Math.max(1, Math.min(3, Math.round(s.count !== undefined ? s.count : 3)));
        root.mPosition = (typeof s.position === "string" && s.position !== "") ? s.position : "top-center";
        root.mAppearance = (s.appearance === "notch") ? "notch" : "island";
        root.mNotchWidth = (typeof s.notchWidth === "number") ? s.notchWidth : 260;
        root.mNotchHeight = (typeof s.notchHeight === "number") ? s.notchHeight : 0;
        root.mNotchOffset = (typeof s.notchOffset === "number") ? s.notchOffset : 0;
        root.mNotchReserve = s.notchReserve !== false;
        let dk = (s.dock && typeof s.dock === "object") ? s.dock : {};
        root.mDockStyle = (dk.style === "joined") ? "joined" : "floating";
        root.mDockSize = (typeof dk.size === "string") ? dk.size : "large";
        root.mDockColumns = (typeof dk.columns === "number") ? dk.columns : 5;
        root.mDockRows = (typeof dk.rows === "number") ? dk.rows : 2;
        root.mDockHero = dk.hero !== false;
        root.mDockQuick = dk.quick !== false;
        root.mDockSearch = dk.search !== false;
        let wt = (s.watcher && typeof s.watcher === "object") ? s.watcher : {};
        root.mWatcherFormat = (wt.format === "12") ? "12" : "24";
        root.mWatcherSeconds = wt.seconds !== false;
        root.mWatcherSpeed = (typeof wt.speed === "number") ? wt.speed : 1.0;
        root.mWatcherMoods = wt.moods !== false;
        root.mWatcherEye = wt.eye === true;
    }
    Component.onCompleted: root.syncFromConfig()

    // Debounced commit into settings.json "mascots".
    property var _pending: ({})
    Timer { id: saveTimer; interval: 300; onTriggered: root.flush() }
    function set(key, v) {
        root._pending[key] = v;
        saveTimer.restart();
    }
    function flush() {
        let keys = Object.keys(root._pending);
        if (keys.length === 0) return;
        let base = (Config.rawSettings.mascots && typeof Config.rawSettings.mascots === "object")
                   ? Config.rawSettings.mascots : {};
        Config.setSetting("mascots", Object.assign({}, base, root._pending));
        root._pending = {};
    }
    // Nested "mascots.dock" commits (merged into the existing dock object).
    property var _pendingDock: ({})
    Timer { id: saveDockTimer; interval: 300; onTriggered: root.flushDock() }
    function setDock(key, v) {
        root._pendingDock[key] = v;
        saveDockTimer.restart();
    }
    function flushDock() {
        let keys = Object.keys(root._pendingDock);
        if (keys.length === 0) return;
        let base = (Config.rawSettings.mascots && typeof Config.rawSettings.mascots === "object")
                   ? Config.rawSettings.mascots : {};
        let dock = (base.dock && typeof base.dock === "object") ? base.dock : {};
        Config.setSetting("mascots", Object.assign({}, base,
            { dock: Object.assign({}, dock, root._pendingDock) }));
        root._pendingDock = {};
    }
    // Nested "mascots.watcher" commits.
    property var _pendingWatcher: ({})
    Timer { id: saveWatcherTimer; interval: 300; onTriggered: root.flushWatcher() }
    function setWatcher(key, v) {
        root._pendingWatcher[key] = v;
        saveWatcherTimer.restart();
    }
    function flushWatcher() {
        let keys = Object.keys(root._pendingWatcher);
        if (keys.length === 0) return;
        let base = (Config.rawSettings.mascots && typeof Config.rawSettings.mascots === "object")
                   ? Config.rawSettings.mascots : {};
        let watcher = (base.watcher && typeof base.watcher === "object") ? base.watcher : {};
        Config.setSetting("mascots", Object.assign({}, base,
            { watcher: Object.assign({}, watcher, root._pendingWatcher) }));
        root._pendingWatcher = {};
    }
    Component.onDestruction: { root.flush(); root.flushDock(); root.flushWatcher(); }

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
                        text: "Mascots"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "A small click-through island at the top of the screen: it fades away while the app launcher (SUPER+D) is open (the island becomes the dock) and when a widget covers it. The mascots' eyes follow the cursor and they react with random moods (angry, surprised, happy, sleepy) when windows or widgets open and close; they fall asleep when idle."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Enabled"
                        checked: root.mEnabled
                        onToggled: { root.mEnabled = !root.mEnabled; root.set("enabled", root.mEnabled); }
                    }

                    Text {
                        text: "Species"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰈸"
                            label: "Flame"
                            active: root.mSpecies !== "cat" && root.mSpecies !== "dog"
                                && root.mSpecies !== "eyes" && root.mSpecies !== "dots"
                                && root.mSpecies !== "watcher"
                                && root.mSpecies !== "mixed"
                            onActivated: { root.mSpecies = "flame"; root.set("species", "flame"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰄛"
                            label: "Cats"
                            active: root.mSpecies === "cat"
                            onActivated: { root.mSpecies = "cat"; root.set("species", "cat"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰩃"
                            label: "Dogs"
                            active: root.mSpecies === "dog"
                            onActivated: { root.mSpecies = "dog"; root.set("species", "dog"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰈈"
                            label: "Eyes"
                            active: root.mSpecies === "eyes"
                            onActivated: { root.mSpecies = "eyes"; root.set("species", "eyes"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰏩"
                            label: "Mixed"
                            active: root.mSpecies === "mixed"
                            onActivated: { root.mSpecies = "mixed"; root.set("species", "mixed"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰇘"
                            label: "Dots"
                            active: root.mSpecies === "dots"
                            onActivated: { root.mSpecies = "dots"; root.set("species", "dots"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰅐"
                            label: "Watcher"
                            active: root.mSpecies === "watcher"
                            onActivated: { root.mSpecies = "watcher"; root.set("species", "watcher"); }
                        }
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Flame is the default little fire; Cats and Dogs are the animal faces (whiskers / muzzle and tongue); Eyes is just a pair of manga eyes; Dots is a cluster of colored dots that trails the cursor; Watcher is a digital clock that retypes each field with a typewriter cursor. Mixed alternates cat / dog / eyes."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Appearance"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "Island"
                            active: root.mAppearance !== "notch"
                            onActivated: { root.mAppearance = "island"; root.set("appearance", "island"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "Notch"
                            active: root.mAppearance === "notch"
                            onActivated: { root.mAppearance = "notch"; root.set("appearance", "notch"); }
                        }
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Island is the floating pill. Notch snaps to the very top edge with a macOS-style silhouette (concave top fillets, rounded bottom, no coloured border) and is only available at the top. The widget dock still unfolds as a floating panel below and retracts the notch while it is open."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    EffectSlider {
                        visible: root.mAppearance === "notch"
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Notch width"
                        from: 140; to: 640; step: 10
                        decimals: 0
                        suffix: "px"
                        accentColor: bar.colors.mauve
                        value: root.mNotchWidth
                        onEdited: (v) => { root.mNotchWidth = v; root.set("notchWidth", v); }
                    }
                    EffectSlider {
                        visible: root.mAppearance === "notch"
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Notch height"
                        from: 0; to: 120; step: 1
                        decimals: 0
                        suffix: "px"
                        accentColor: bar.colors.mauve
                        value: root.mNotchHeight
                        onEdited: (v) => { root.mNotchHeight = v; root.set("notchHeight", v); }
                    }
                    EffectSlider {
                        visible: root.mAppearance === "notch"
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Notch offset Y"
                        from: -60; to: 60; step: 1
                        decimals: 0
                        suffix: "px"
                        accentColor: bar.colors.mauve
                        value: root.mNotchOffset
                        onEdited: (v) => { root.mNotchOffset = v; root.set("notchOffset", v); }
                    }
                    EditLabel {
                        visible: root.mAppearance === "notch"
                        bar: root.bar
                        width: parent.width
                        text: "Height 0 keeps the automatic height. Offset Y moves the notch up (negative) or down (positive); a negative value tucks the top fillets above the screen edge for a flatter top."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                    ToggleCard {
                        visible: root.mAppearance === "notch"
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Reserve top space"
                        checked: root.mNotchReserve
                        onToggled: { root.mNotchReserve = !root.mNotchReserve; root.set("notchReserve", root.mNotchReserve); }
                    }
                    EditLabel {
                        visible: root.mAppearance === "notch"
                        bar: root.bar
                        width: parent.width
                        text: "Reserve top space keeps maximized windows clear of the notch (an exclusive zone, like real hardware). Turn it off to let windows slide underneath."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Position"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(6)
                        rowSpacing: bar.s(6)
                        Repeater {
                            model: ["top-left", "top-center", "top-right",
                                    "center-left", "center", "center-right",
                                    "bottom-left", "bottom-center", "bottom-right"]
                            delegate: Rectangle {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: bar.s(22)
                                radius: bar.s(6)
                                color: root.mPosition === modelData
                                    ? bar.colors.mauve
                                    : (posMa.containsMouse ? Qt.alpha(bar.colors.mauve, 0.12)
                                                           : Qt.alpha(bar.colors.surface0, 0.4))
                                border.width: 1
                                border.color: root.mPosition === modelData
                                    ? bar.colors.mauve : bar.colors.surface1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                MouseArea {
                                    id: posMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.mPosition = modelData;
                                        root.set("position", modelData);
                                    }
                                }
                            }
                        }
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "The island moves to the chosen corner/edge; the widget dock unfolds inward (downwards, or upwards when the island sits at the bottom)."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "How many"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰬺"
                            label: "One"
                            active: root.mCount === 1
                            onActivated: { root.mCount = 1; root.set("count", 1); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰬻"
                            label: "Two"
                            active: root.mCount === 2
                            onActivated: { root.mCount = 2; root.set("count", 2); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: "󰬼"
                            label: "Three"
                            active: root.mCount === 3
                            onActivated: { root.mCount = 3; root.set("count", 3); }
                        }
                    }

                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Size"
                        from: 0.6; to: 1.6; step: 0.1
                        decimals: 1
                        suffix: "x"
                        accentColor: bar.colors.mauve
                        value: root.mSize
                        onEdited: (v) => { root.mSize = v; root.set("size", v); }
                    }

                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: root.mEnabled
                            ? "Open the launcher (SUPER+D): the island fades away into the dock and comes back when you close it. The mascots eyes follow the cursor."
                            : "Enable to show the island; the overlay is click-through and never blocks the windows below."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Dock"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "The control center that unfolds when you click the island/notch: search, clock + now-playing, quick actions and a widget grid."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "Floating"
                            active: root.mDockStyle !== "joined"
                            onActivated: { root.mDockStyle = "floating"; root.setDock("style", "floating"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "Joined to notch"
                            active: root.mDockStyle === "joined"
                            onActivated: { root.mDockStyle = "joined"; root.setDock("style", "joined"); }
                        }
                    }
                    GridLayout {
                        width: parent.width
                        columns: 4
                        columnSpacing: bar.s(8)
                        rowSpacing: bar.s(8)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "S"
                            active: root.mDockSize === "compact"
                            onActivated: { root.mDockSize = "compact"; root.setDock("size", "compact"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "M"
                            active: root.mDockSize === "medium"
                            onActivated: { root.mDockSize = "medium"; root.setDock("size", "medium"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "L"
                            active: root.mDockSize === "large"
                            onActivated: { root.mDockSize = "large"; root.setDock("size", "large"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "XL"
                            active: root.mDockSize === "wide"
                            onActivated: { root.mDockSize = "wide"; root.setDock("size", "wide"); }
                        }
                    }
                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Grid columns"
                        from: 3; to: 7; step: 1
                        decimals: 0
                        suffix: ""
                        accentColor: bar.colors.mauve
                        value: root.mDockColumns
                        onEdited: (v) => { root.mDockColumns = v; root.setDock("columns", v); }
                    }
                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Grid rows"
                        from: 1; to: 3; step: 1
                        decimals: 0
                        suffix: ""
                        accentColor: bar.colors.mauve
                        value: root.mDockRows
                        onEdited: (v) => { root.mDockRows = v; root.setDock("rows", v); }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Hero (clock + now playing)"
                        checked: root.mDockHero
                        onToggled: { root.mDockHero = !root.mDockHero; root.setDock("hero", root.mDockHero); }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Quick actions"
                        checked: root.mDockQuick
                        onToggled: { root.mDockQuick = !root.mDockQuick; root.setDock("quick", root.mDockQuick); }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Search field"
                        checked: root.mDockSearch
                        onToggled: { root.mDockSearch = !root.mDockSearch; root.setDock("search", root.mDockSearch); }
                    }

                    Text {
                        text: "Watcher"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Options for the Watcher species: a digital clock retyped with a typewriter cursor."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(10)
                        rowSpacing: bar.s(10)
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "24-hour"
                            active: root.mWatcherFormat !== "12"
                            onActivated: { root.mWatcherFormat = "24"; root.setWatcher("format", "24"); }
                        }
                        OptionCard {
                            Layout.fillWidth: true
                            bar: root.bar
                            icon: ""
                            label: "12-hour"
                            active: root.mWatcherFormat === "12"
                            onActivated: { root.mWatcherFormat = "12"; root.setWatcher("format", "12"); }
                        }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Show seconds"
                        checked: root.mWatcherSeconds
                        onToggled: { root.mWatcherSeconds = !root.mWatcherSeconds; root.setWatcher("seconds", root.mWatcherSeconds); }
                    }
                    EffectSlider {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Typewriter speed"
                        from: 0.5; to: 2.5; step: 0.1
                        decimals: 1
                        suffix: "x"
                        accentColor: bar.colors.mauve
                        value: root.mWatcherSpeed
                        onEdited: (v) => { root.mWatcherSpeed = v; root.setWatcher("speed", v); }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Mood effects"
                        checked: root.mWatcherMoods
                        onToggled: { root.mWatcherMoods = !root.mWatcherMoods; root.setWatcher("moods", root.mWatcherMoods); }
                    }
                    ToggleCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Watcher eye"
                        checked: root.mWatcherEye
                        onToggled: { root.mWatcherEye = !root.mWatcherEye; root.setWatcher("eye", root.mWatcherEye); }
                    }

                    Text {
                        text: "Profiles"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Save the current mascot + notch + dock + watcher settings as a named profile and load it later."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                    FieldCard {
                        width: parent.width
                        bar: root.bar
                        label: "Name"
                        value: root.mProfileName
                        placeholder: "e.g. minimal"
                        onEdited: (t) => { root.mProfileName = t; }
                    }
                    OptionCard {
                        width: parent.width
                        bar: root.bar
                        icon: ""
                        label: "Save current as profile"
                        active: false
                        onActivated: root.saveProfile(root.mProfileName)
                    }
                    Repeater {
                        model: root.profileNames
                        delegate: Item {
                            required property string modelData
                            width: parent.width
                            height: bar.s(28)
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                font.family: "Hack Nerd Font"
                                font.pixelSize: bar.s(12)
                                color: bar.colors.text
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: bar.s(58); height: bar.s(22); radius: bar.s(7)
                                color: ldMa.containsMouse ? Qt.alpha(bar.colors.green, 0.2) : Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1; border.color: bar.colors.surface1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Load"
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: bar.s(10)
                                    color: bar.colors.text
                                }
                                MouseArea {
                                    id: ldMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.loadProfile(modelData)
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: bar.s(64)
                                anchors.verticalCenter: parent.verticalCenter
                                width: bar.s(58); height: bar.s(22); radius: bar.s(7)
                                color: dlMa.containsMouse ? Qt.alpha(bar.colors.red, 0.2) : Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1; border.color: bar.colors.surface1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Delete"
                                    font.family: "Hack Nerd Font"
                                    font.pixelSize: bar.s(10)
                                    color: bar.colors.text
                                }
                                MouseArea {
                                    id: dlMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteProfile(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
