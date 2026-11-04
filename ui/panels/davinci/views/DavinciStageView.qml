import QtQuick
import QtQuick.Layouts
import "../../../../core"

// ---------------------------------------------------------------------------
// DavinciStageView - focused presentation mode.
//
// One large preview plus a filmstrip. The filmstrip is the navigable model
// (currentIndex), so keyboard focus, apply-to-current and the root shortcuts
// keep working exactly like the cover-flow view. Videos and scenes are shown
// with their normal thumbnail and apply through ctx.applyWallpaper.
// ---------------------------------------------------------------------------
Item {
    id: root

    required property var ctx
    required property var theme

    property int currentIndex: strip.currentIndex
    readonly property int count: strip.count
    readonly property var currentItem: {
        let model = root.ctx.activeModel;
        if (!model || strip.currentIndex < 0 || strip.currentIndex >= model.count) return null;
        return model.get(strip.currentIndex);
    }

    function centerView(index) {
        strip.positionViewAtIndex(index, ListView.Center);
    }
    function positionViewAtIndex(index, mode) {
        strip.positionViewAtIndex(index, mode);
    }
    function forceLayout() {
        strip.forceLayout();
    }
    function forceActiveFocus() {
        strip.forceActiveFocus();
    }

    onCurrentIndexChanged: {
        if (strip.currentIndex !== root.currentIndex)
            strip.currentIndex = root.currentIndex;
    }

    Connections {
        target: strip
        function onCurrentIndexChanged() {
            root.currentIndex = strip.currentIndex;
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.ctx.s(24)
        anchors.bottomMargin: root.ctx.showFilmstrip ? root.ctx.s(96) : root.ctx.s(24)

        Rectangle {
            id: hero
            anchors.fill: parent
            radius: root.ctx.s(18)
            clip: true
            color: root.theme.base
            border.width: 1
            border.color: Theme.outlineVariant

            Image {
                anchors.fill: parent
                source: root.currentItem ? root.currentItem.fileUrl : ""
                sourceSize: Qt.size(1600, 900)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: root.ctx.s(22)
                spacing: root.ctx.s(4)

                Text {
                    text: root.currentItem
                        ? String(root.ctx.getCleanName(root.currentItem.fileName)).split("/").pop()
                        : "No selection"
                    color: root.theme.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(28)
                    font.bold: true
                }

                Text {
                    visible: root.ctx.showMetadata
                    text: root.currentItem
                        ? (String(root.currentItem.fileName).startsWith("scn_")
                            ? "Interactive scene - applies through xwww"
                            : String(root.currentItem.fileName).startsWith("000_")
                                ? "Video - applies through mpvpaper"
                                : "Image - applies through xwww")
                        : ""
                    color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.64)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(11)
                }
            }

            // Per-monitor and quick actions. The monitor selector itself is
            // shared with the filter bar; these buttons only use the same root
            // state.
            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.ctx.s(22)
                spacing: root.ctx.s(8)

                Rectangle {
                    width: root.ctx.s(220)
                    height: root.ctx.s(48)
                    radius: root.ctx.s(11)
                    color: root.theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Apply to current"
                        color: root.theme.crust
                        font.family: "Hack Nerd Font"
                        font.pixelSize: root.ctx.s(13)
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.currentItem) return;
                            let name = String(root.currentItem.fileName);
                            root.ctx.applyWallpaper(name, name.startsWith("000_"));
                        }
                    }
                }

                Rectangle {
                    width: root.ctx.s(220)
                    height: root.ctx.s(44)
                    radius: root.ctx.s(11)
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: root.currentItem && root.ctx.isFavorite(String(root.currentItem.fileName))
                            ? "Favorite on"
                            : "Favorite"
                        color: root.theme.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: root.ctx.s(10)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentItem)
                                root.ctx.toggleFavorite(String(root.currentItem.fileName));
                        }
                    }
                }

                Rectangle {
                    width: root.ctx.s(220)
                    height: root.ctx.s(44)
                    radius: root.ctx.s(11)
                    color: root.ctx.slideshowOn
                        ? Qt.rgba(root.theme.mauve.r, root.theme.mauve.g, root.theme.mauve.b, 0.22)
                        : Theme.surfaceContainer
                    border.width: 1
                    border.color: root.ctx.slideshowOn ? root.theme.mauve : Theme.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: root.ctx.slideshowOn ? "Slideshow on" : "Slideshow"
                        color: root.theme.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: root.ctx.s(10)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ctx.toggleSlideshow()
                    }
                }

                Rectangle {
                    width: root.ctx.s(220)
                    height: root.ctx.s(44)
                    radius: root.ctx.s(11)
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: "Transition: " + root.ctx.transition
                        color: root.theme.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: root.ctx.s(9)
                        elide: Text.ElideRight
                        width: parent.width - root.ctx.s(12)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let list = root.ctx.transitions;
                            let i = list.indexOf(root.ctx.transition);
                            root.ctx.transition = list[(i + 1) % list.length];
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: root.ctx.showShortcuts
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.ctx.s(26)
        anchors.bottomMargin: root.ctx.showFilmstrip ? root.ctx.s(92) : root.ctx.s(26)
        text: "Left/Right navigate - Enter apply - Space slideshow"
        color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.45)
        font.family: "Hack Nerd Font"
        font.pixelSize: root.ctx.s(9)
    }

    // Filmstrip: the actual navigation model for keyboard and focus.
    Rectangle {
        visible: root.ctx.showFilmstrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.ctx.s(24)
        anchors.rightMargin: root.ctx.s(24)
        anchors.bottomMargin: root.ctx.s(20)
        height: root.ctx.s(64)
        radius: root.ctx.s(12)
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outlineVariant

        ListView {
            id: strip
            anchors.fill: parent
            anchors.margins: root.ctx.s(7)
            orientation: ListView.Horizontal
            spacing: root.ctx.s(6)
            clip: true
            cacheBuffer: 2000
            focus: true
            model: root.ctx.activeModel

            onCurrentIndexChanged: root.currentIndex = currentIndex

            delegate: Rectangle {
                width: root.ctx.s(82)
                height: root.ctx.s(48)
                radius: root.ctx.s(6)
                clip: true
                color: root.theme.base
                border.width: index === strip.currentIndex ? root.ctx.s(2) : 1
                border.color: index === strip.currentIndex ? root.theme.text : Theme.outlineVariant

                Image {
                    anchors.fill: parent
                    source: fileUrl
                    sourceSize: Qt.size(180, 100)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        strip.currentIndex = index;
                        root.ctx.applyWallpaper(String(fileName), String(fileName).startsWith("000_"));
                    }
                }
            }
        }
    }
}
