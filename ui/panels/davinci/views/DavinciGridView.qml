import QtQuick
import "../components/grid"

// ---------------------------------------------------------------------------
// DavinciGridView - responsive thumbnail grid.
//
// The view owns only presentation and the current index. The picker root
// owns the model, filters, search and apply logic; activating a tile always
// calls ctx.applyWallpaper so xwww scenes, videos and images keep the same
// behaviour as the cover-flow view.
// ---------------------------------------------------------------------------
Item {
    id: root

    required property var ctx
    required property var theme
    property int columns: 4

    property int currentIndex: grid.currentIndex
    readonly property int count: grid.count

    function centerView(index) {
        grid.positionViewAtIndex(index, GridView.Center);
    }
    function positionViewAtIndex(index, mode) {
        grid.positionViewAtIndex(index, mode);
    }
    function forceLayout() {
        grid.forceLayout();
    }
    function forceActiveFocus() {
        grid.forceActiveFocus();
    }

    onCurrentIndexChanged: {
        if (grid.currentIndex !== root.currentIndex)
            grid.currentIndex = root.currentIndex;
    }

    Connections {
        target: grid
        function onCurrentIndexChanged() {
            root.currentIndex = grid.currentIndex;
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: root.ctx.s(20)
        cellWidth: Math.max(1, Math.floor(width / Math.max(1, root.columns)))
        cellHeight: Math.max(1, Math.floor(cellWidth * 0.78))
        model: root.ctx.activeModel
        clip: true
        cacheBuffer: 4000
        focus: true

        onCurrentIndexChanged: root.currentIndex = currentIndex

        delegate: DavinciTile {
            width: grid.cellWidth
            height: grid.cellHeight
            ctx: root.ctx
            theme: root.theme
            selected: index === grid.currentIndex
            onActivated: {
                grid.currentIndex = index;
                root.ctx.applyWallpaper(String(fileName), String(fileName).startsWith("000_"));
            }
            onFavoriteToggled: root.ctx.toggleFavorite(String(fileName))
        }
    }
}
