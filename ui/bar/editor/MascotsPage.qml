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

    // Same defaults ui/mascots/MascotsOverlay.qml falls back to.
    property bool mEnabled: false
    property real mSize: 1.0
    property string mSpecies: "flame"
    property int mCount: 3
    property string mPosition: "top-center"

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
    Component.onDestruction: root.flush()

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
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Flame is the default little fire; Cats and Dogs are the animal faces (whiskers / muzzle and tongue); Eyes is just a pair of manga eyes; Dots is a cluster of colored dots that trails the cursor. Mixed alternates cat / dog / eyes."
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
                }
            }
        }
    }
}
