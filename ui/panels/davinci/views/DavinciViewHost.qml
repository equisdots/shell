import QtQuick
import "."
import "../components/grid"

// ---------------------------------------------------------------------------
// DavinciViewHost - loads one view mode and exposes a single navigation
// contract to DavinciPicker.qml:
//
//   currentIndex, count, setCurrentIndex(index), centerView(index),
//   positionViewAtIndex(index, mode), forceLayout(), forceActiveFocus()
//
// Every view owns only presentation. The picker root keeps the models,
// filters, search, apply and personalization state.
// ---------------------------------------------------------------------------
Item {
    id: host

    required property var ctx
    required property var theme
    property string mode: "coverflow"
    property int gridColumns: 4

    property var view: null
    property int currentIndex: -1
    property int count: 0
    signal viewLoaded()

    function componentFor(name) {
        switch (name) {
        case "grid":    return gridComp;
        case "library": return libraryComp;
        case "stage":   return stageComp;
        case "palette": return paletteComp;
        default:        return coverComp;
        }
    }

    function adopt(item) {
        view = item;
        if (item && item.currentIndexChanged)
            item.currentIndexChanged.connect(sync);
        sync();
        // The model may have loaded before the view (or vice versa). Apply the
        // current filter once the view exists so the first visible card gets
        // focus and the highlight/scale are correct on every mode.
        if (ctx && ctx.applyFilters)
            ctx.applyFilters(true);
        viewLoaded();
    }

    function sync() {
        if (!view) {
            currentIndex = -1;
            count = 0;
            return;
        }
        count = view.count;
        if (currentIndex !== view.currentIndex) {
            currentIndex = view.currentIndex;
            if (ctx && ctx.gridIndexChanged)
                ctx.gridIndexChanged();
        }
    }

    function setCurrentIndex(index) {
        if (view && view.currentIndex !== index)
            view.currentIndex = index;
        sync();
    }

    function centerView(index) {
        if (view && view.centerView)
            view.centerView(index);
        else if (view && view.positionViewAtIndex)
            view.positionViewAtIndex(index, 4);
    }

    function positionViewAtIndex(index, mode) {
        if (view && view.positionViewAtIndex)
            view.positionViewAtIndex(index, mode);
    }

    function forceLayout() {
        if (view && view.forceLayout)
            view.forceLayout();
    }

    function forceActiveFocus() {
        if (view && view.forceActiveFocus)
            view.forceActiveFocus();
    }

    // Re-center after the master window finishes its morph/resize. The picker
    // is created while the window is 1px wide and grows through an animation;
    // an early centerView() is reset by that growth.
    Timer {
        id: settleTimer
        interval: 1000
        onTriggered: {
            if (host.currentIndex >= 0)
                host.centerView(host.currentIndex);
        }
    }
    onWidthChanged: settleTimer.restart()
    onHeightChanged: settleTimer.restart()

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: host.componentFor(host.mode)
        onLoaded: host.adopt(item)
    }

    Component {
        id: coverComp
        DavinciGrid {
            width: loader.width
            height: loader.height
            ctx: host.ctx
            theme: host.theme
        }
    }

    Component {
        id: gridComp
        DavinciGridView {
            width: loader.width
            height: loader.height
            ctx: host.ctx
            theme: host.theme
            columns: host.gridColumns
        }
    }

    Component {
        id: libraryComp
        DavinciLibraryView {
            width: loader.width
            height: loader.height
            ctx: host.ctx
            theme: host.theme
        }
    }

    Component {
        id: stageComp
        DavinciStageView {
            width: loader.width
            height: loader.height
            ctx: host.ctx
            theme: host.theme
        }
    }

    Component {
        id: paletteComp
        DavinciPaletteView {
            width: loader.width
            height: loader.height
            ctx: host.ctx
            theme: host.theme
        }
    }
}
