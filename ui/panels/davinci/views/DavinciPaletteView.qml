import QtQuick
import "../../../../core"
import "../components/grid"

// ---------------------------------------------------------------------------
// DavinciPaletteView - dense, keyboard-first list.
//
// This is not the global command palette overlay; it is a view mode inside
// the picker. It keeps the same active model and apply semantics, so search
// results, scenes and videos behave like every other mode.
// ---------------------------------------------------------------------------
Item {
    id: root

    required property var ctx
    required property var theme

    property int currentIndex: list.currentIndex
    readonly property int count: list.count

    function centerView(index) {
        list.positionViewAtIndex(index, ListView.Center);
    }
    function positionViewAtIndex(index, mode) {
        list.positionViewAtIndex(index, mode);
    }
    function forceLayout() {
        list.forceLayout();
    }
    function forceActiveFocus() {
        list.forceActiveFocus();
    }

    onCurrentIndexChanged: {
        if (list.currentIndex !== root.currentIndex)
            list.currentIndex = root.currentIndex;
    }

    Connections {
        target: list
        function onCurrentIndexChanged() {
            root.currentIndex = list.currentIndex;
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: root.ctx.s(24)
        anchors.topMargin: root.ctx.s(12)
        spacing: root.ctx.s(4)
        clip: true
        cacheBuffer: 3000
        focus: true
        model: root.ctx.activeModel

        onCurrentIndexChanged: root.currentIndex = currentIndex

        delegate: DavinciRow {
            width: list.width
            ctx: root.ctx
            theme: root.theme
            selected: index === list.currentIndex
            onActivated: {
                list.currentIndex = index;
                root.ctx.applyWallpaper(String(fileName), String(fileName).startsWith("000_"));
            }
            onFavoriteToggled: root.ctx.toggleFavorite(String(fileName))
        }
    }
}
