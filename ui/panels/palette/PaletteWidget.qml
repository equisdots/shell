import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../core"
import "../../bar"

// ═══════════════════════════════════════════════════════════════════════════
// PaletteWidget — standalone palette switcher (SUPER + SHIFT + P).
//
// Same selector as the editor's Palette page (PalettePage.qml): sections
// X / Custom / User, cards with a 2x2 swatch preview and the palette name.
// Clicking a card writes bar.palette to settings.json (Config.setSetting,
// the same write the editor uses), so the bar, window borders and desktop
// widgets recolor live, and the widget closes itself like a quick switcher.
//
// Its position is configurable through the shared popup override:
//   settings.json -> widgets.palette.position
// ("default", top/center/bottom x left/center/right). See
// core/WindowRegistry.js (positionLayout) and docs/windows.md.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: window

    Colors { id: _theme }

    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val) }

    // ── data ────────────────────────────────────────────────────────────────
    readonly property string palettesDir: Quickshell.env("HOME")
        + "/.config/hypr/scripts/quickshell/dock/palettes"
    property var palettes: []
    property string filter: ""

    // Active slug; depends on Config.rev because rawSettings is mutated
    // in place by setSetting (same trick the editor pages use).
    readonly property string activeSlug: (Config.rev,
        (Config.rawSettings.bar && Config.rawSettings.bar.palette) || "x")

    readonly property var sections: [
        { id: "x",      label: "X" },
        { id: "custom", label: "Custom" },
        { id: "user",   label: "User" }
    ]

    function palettesOf(category, query) {
        let q = String(query || "").trim().toLowerCase();
        let out = [];
        for (let i = 0; i < window.palettes.length; i++) {
            let p = window.palettes[i];
            if (!p || String(p.category || "x") !== category) continue;
            if (q !== "" && String(p.name).toLowerCase().indexOf(q) === -1
                && String(p.slug).toLowerCase().indexOf(q) === -1) continue;
            out.push(p);
        }
        return out;
    }

    // Re-read the index every time the widget is shown so palettes created
    // after the shell started appear without a reload.
    Process {
        id: indexProcess
        command: ["cat", window.palettesDir + "/index.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    window.palettes = JSON.parse(this.text.trim());
                } catch (e) {
                    window.palettes = [];
                }
            }
        }
    }

    function reloadIndex() {
        indexProcess.running = false;
        indexProcess.running = true;
    }

    Component.onCompleted: reloadIndex()
    onVisibleChanged: if (visible) reloadIndex()

    function applyPalette(slug) {
        let next = Object.assign({}, Config.rawSettings.bar || {}, { palette: slug });
        Config.setSetting("bar", next);
        Quickshell.execDetached(["bash", Quickshell.env("HOME")
            + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    // ── UI ──────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: window.base
        radius: window.s(16)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(18)
            spacing: window.s(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(10)

                Text {
                    text: "Palette"
                    font.family: "Hack Nerd Font"
                    font.weight: Font.Black
                    font.pixelSize: window.s(22)
                    color: window.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: window.activeSlug
                    font.family: "Hack Nerd Font"
                    font.pixelSize: window.s(12)
                    color: window.subtext0
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: window.s(20)
                    height: window.s(20)
                    radius: window.s(10)
                    color: window.mauve
                }
            }

            TextField {
                id: filterField
                Layout.fillWidth: true
                placeholderText: "Filter palettes"
                color: window.text
                placeholderTextColor: Qt.alpha(window.subtext0, 0.7)
                font.family: "Hack Nerd Font"
                font.pixelSize: window.s(12)
                leftPadding: window.s(12)
                rightPadding: window.s(12)
                onTextChanged: window.filter = text
                background: Rectangle {
                    radius: window.s(12)
                    color: Qt.alpha(window.surface0, 0.4)
                    border.width: 1
                    border.color: window.surface1
                }
            }

            Flickable {
                id: pageFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: listCol.height + window.s(8)
                ScrollBar.vertical: ScrollBar {
                    id: vScroll
                    width: window.s(4)
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    active: pageFlick.moving || vScroll.hovered
                    contentItem: Rectangle {
                        radius: window.s(2)
                        color: window.surface2
                        opacity: vScroll.active ? 1.0 : 0.45
                    }
                    background: Item {}
                }

                Column {
                    id: listCol
                    width: pageFlick.width
                    spacing: window.s(10)

                    Text {
                        width: parent.width
                        visible: window.palettes.length === 0
                        topPadding: window.s(16)
                        horizontalAlignment: Text.AlignHCenter
                        text: "No palettes found"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: window.s(12)
                        color: window.subtext0
                    }

                    Repeater {
                        model: window.sections

                        delegate: Column {
                            required property var modelData
                            readonly property var entries: window.palettesOf(modelData.id, window.filter)

                            width: listCol.width
                            spacing: window.s(10)
                            visible: entries.length > 0

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.label
                                font.family: "Hack Nerd Font"
                                font.weight: Font.Black
                                font.pixelSize: window.s(15)
                                color: window.text
                            }

                            GridLayout {
                                width: parent.width
                                columns: 3
                                columnSpacing: window.s(8)
                                rowSpacing: window.s(8)

                                Repeater {
                                    model: parent.parent.entries
                                    delegate: PaletteCard {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Palette card: 2x2 swatch preview + name; click applies and closes.
    component PaletteCard: Rectangle {
        id: palCard
        required property var modelData
        readonly property var pal: modelData
        readonly property bool isSel: window.activeSlug === pal.slug
        readonly property bool hovered: palMa.containsMouse

        Layout.fillWidth: true
        height: window.s(45)
        radius: window.s(18)
        color: palCard.isSel ? window.mauve
             : (palCard.hovered ? Qt.alpha(window.mauve, 0.12)
                                : Qt.alpha(window.surface0, 0.4))
        border.width: 1
        border.color: (palCard.isSel || palCard.hovered) ? window.mauve : window.surface1
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: window.s(10)
            spacing: window.s(10)

            Item {
                Layout.preferredWidth: window.s(24)
                Layout.preferredHeight: window.s(24)
                Column {
                    anchors.centerIn: parent
                    spacing: window.s(2)
                    Row {
                        spacing: window.s(2)
                        Repeater {
                            model: [0, 1]
                            delegate: Rectangle {
                                width: window.s(9); height: window.s(9)
                                radius: window.s(2)
                                color: palCard.pal.colors[index]
                            }
                        }
                    }
                    Row {
                        spacing: window.s(2)
                        Repeater {
                            model: [0, 1]
                            delegate: Rectangle {
                                width: window.s(9); height: window.s(9)
                                radius: window.s(2)
                                color: palCard.pal.colors[2 + index]
                            }
                        }
                    }
                }
            }

            Text {
                text: palCard.pal.name
                font.family: "Hack Nerd Font"
                font.weight: palCard.isSel ? Font.Bold : Font.Medium
                font.pixelSize: window.s(12)
                color: palCard.isSel ? window.crust : window.text
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: palMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: window.applyPalette(palCard.pal.slug)
        }
    }
}
