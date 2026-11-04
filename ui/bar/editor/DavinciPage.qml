import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../edit"
import "../../../core"
import "../../../core/Personalization.js" as Personalization
import "../../panels/davinci/lib/constants.js" as C

// ---------------------------------------------------------------------------
// DavinciPage - main settings page for the wallpaper picker.
//
// Every option is stored in settings.json under the "davinci" section and is
// consumed by the picker root (view mode, layout, visibility) or by the
// Personalization API. The page does not know about individual view
// components; adding a mode only requires a new entry in viewModes and a view
// in shell/ui/panels/davinci/views.
// ---------------------------------------------------------------------------
Item {
    id: root
    anchors.fill: parent
    property var bar: null
    property int tick: 0

    readonly property var cfg: (tick, Personalization.normalize("davinci", Config.rawSettings.davinci))
    readonly property var viewModes: [
        { id: "coverflow", label: "Cover Flow", icon: "▦" },
        { id: "grid",      label: "Grid",       icon: "▤" },
        { id: "library",   label: "Library",    icon: "☰" },
        { id: "stage",     label: "Stage",      icon: "▣" },
        { id: "palette",   label: "Palette",    icon: "≡" }
    ]
    readonly property var shapeValues: ["rect", "square", "circle"]
    readonly property var shapeLabels: ["Rect", "Square", "Circle"]
    readonly property var orientationValues: ["horizontal", "vertical"]
    readonly property var orientationLabels: ["Horizontal", "Vertical"]
    readonly property var kindValues: ["image", "video"]
    readonly property var kindLabels: ["Image", "Video"]

    function setOpt(key, value) {
        let raw = Object.assign({}, Config.rawSettings.davinci || {});
        raw[key] = value;
        Config.setSetting("davinci", raw);
        root.tick++;
    }

    function resetOptions() {
        let raw = Config.rawSettings.davinci || {};
        let out = Object.assign({}, Personalization.defaults("davinci"), {
            favorites: Array.isArray(raw.favorites) ? raw.favorites : []
        });
        Config.setSetting("davinci", out);
        root.tick++;
    }

    function cycle(values, current, delta) {
        let i = values.indexOf(current);
        if (i === -1) i = 0;
        return values[(i + delta + values.length) % values.length];
    }

    function activeSources() {
        return C.SEARCH_SOURCES.filter(function (s) { return s.kind === root.cfg.searchKind; });
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
                contentHeight: pageCol.height + bar.s(Theme.gapLg)
                ScrollBar.vertical: ScrollBar {
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius: bar.s(Theme.radiusXs)
                        color: Theme.surfaceContainerHighest
                        opacity: parent.active ? 1 : 0.45
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
                        text: "Davinci wallpaper picker"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(24)
                        color: bar.colors.text
                    }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "View modes, grid density, visible controls and picker behaviour. These options live in settings.json under \"davinci\"; the wallpaper engine contracts (xwww scenes, mpvpaper videos, images) are unchanged."
                        font.pixelSize: bar.s(12)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }

                    SectionTitle { bar: root.bar; text: "View mode" }
                    EditLabel {
                        bar: root.bar
                        width: parent.width
                        text: "Choose the default presentation. Every mode shares the same models, filters, favourites, search and apply path."
                        font.pixelSize: bar.s(11)
                        color: bar.colors.subtext0
                        wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(Theme.gapSm)
                        rowSpacing: bar.s(Theme.gapSm)

                        Repeater {
                            model: root.viewModes
                            delegate: OptionCard {
                                required property var modelData
                                bar: root.bar
                                Layout.fillWidth: true
                                icon: modelData.icon
                                label: modelData.label
                                active: root.cfg.viewMode === modelData.id
                                onActivated: root.setOpt("viewMode", modelData.id)
                            }
                        }
                    }

                    SectionTitle { bar: root.bar; text: "Layout" }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(Theme.gapSm)
                        rowSpacing: bar.s(Theme.gapSm)

                        CycleCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            icon: "󰏘"
                            label: "Card shape"
                            model: root.shapeLabels
                            index: Math.max(0, root.shapeValues.indexOf(root.cfg.cardShape))
                            onStepped: (delta) => root.setOpt("cardShape", root.cycle(root.shapeValues, root.cfg.cardShape, delta))
                        }
                        CycleCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            icon: "󰆟"
                            label: "Cover-flow orientation"
                            model: root.orientationLabels
                            index: Math.max(0, root.orientationValues.indexOf(root.cfg.gridOrientation))
                            onStepped: (delta) => root.setOpt("gridOrientation", root.cycle(root.orientationValues, root.cfg.gridOrientation, delta))
                        }
                        StepperCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            label: "Grid columns"
                            value: String(root.cfg.gridColumns)
                            onDec: root.setOpt("gridColumns", Math.max(2, root.cfg.gridColumns - 1))
                            onInc: root.setOpt("gridColumns", Math.min(8, root.cfg.gridColumns + 1))
                        }
                        StepperCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            label: "Slideshow interval"
                            value: Math.round(root.cfg.slideshowInterval / 60) + " min"
                            onDec: root.setOpt("slideshowInterval", Math.max(60, root.cfg.slideshowInterval - 60))
                            onInc: root.setOpt("slideshowInterval", Math.min(3600, root.cfg.slideshowInterval + 60))
                        }
                        CycleCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            icon: "󰔟"
                            label: "Transition"
                            model: C.TRANSITIONS
                            index: Math.max(0, C.TRANSITIONS.indexOf(root.cfg.transition))
                            onStepped: (delta) => root.setOpt("transition", root.cycle(C.TRANSITIONS, root.cfg.transition, delta))
                        }
                        CycleCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            icon: "󰍉"
                            label: "Search kind"
                            model: root.kindLabels
                            index: Math.max(0, root.kindValues.indexOf(root.cfg.searchKind))
                            onStepped: (delta) => root.setOpt("searchKind", root.cycle(root.kindValues, root.cfg.searchKind, delta))
                        }
                        CycleCard {
                            bar: root.bar
                            Layout.fillWidth: true
                            icon: "󰖟"
                            label: "Search source"
                            model: root.activeSources().map(function (s) { return s.label; })
                            index: Math.max(0, root.activeSources().map(function (s) { return s.id; }).indexOf(root.cfg.searchSource))
                            onStepped: (delta) => {
                                let list = root.activeSources();
                                if (list.length === 0) return;
                                let ids = list.map(function (s) { return s.id; });
                                let next = root.cycle(ids, root.cfg.searchSource, delta);
                                root.setOpt("searchSource", next);
                            }
                        }
                    }

                    SectionTitle { bar: root.bar; text: "Visible controls" }
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(Theme.gapSm)
                        rowSpacing: bar.s(Theme.gapSm)

                        Repeater {
                            model: [
                                { key: "showFilterBar", label: "Filter bar" },
                                { key: "showStatus", label: "Status drawer" },
                                { key: "showMonitors", label: "Monitor selector" },
                                { key: "showColorFilters", label: "Color filters" },
                                { key: "showTransition", label: "Transition picker" },
                                { key: "showSlideshow", label: "Slideshow button" },
                                { key: "showPalettePreview", label: "Palette preview" },
                                { key: "showSearch", label: "Search controls" },
                                { key: "showKeys", label: "Provider keys button" },
                                { key: "showFilmstrip", label: "Filmstrip (stage)" },
                                { key: "showSidebar", label: "Sidebar (library)" },
                                { key: "showInspector", label: "Inspector (library)" },
                                { key: "showMetadata", label: "Metadata captions" },
                                { key: "showShortcuts", label: "Keyboard hints" },
                                { key: "roundedThumbs", label: "Rounded thumbnails" }
                            ]
                            delegate: ToggleCard {
                                required property var modelData
                                bar: root.bar
                                Layout.fillWidth: true
                                label: modelData.label
                                checked: root.cfg[modelData.key] !== false
                                onToggled: root.setOpt(modelData.key, !(root.cfg[modelData.key] !== false))
                            }
                        }
                    }

                    SectionTitle { bar: root.bar; text: "Reset" }
                    OptionCard {
                        bar: root.bar
                        width: parent.width
                        icon: "󰔄"
                        label: "Reset davinci options (favourites are kept)"
                        onActivated: root.resetOptions()
                    }
                }
            }
        }
    }
}
