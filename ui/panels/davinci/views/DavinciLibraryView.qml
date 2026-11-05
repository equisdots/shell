import QtQuick
import QtQuick.Layouts
import "../../../../core"
import "../components/grid"

// ---------------------------------------------------------------------------
// DavinciLibraryView - collection sidebar, thumbnail grid and inspector.
//
// The sidebar only changes ctx.currentFilter, so the same model and apply
// path are used everywhere. The inspector reads the active model item and
// never mutates the library.
// ---------------------------------------------------------------------------
Item {
    id: root

    required property var ctx
    required property var theme

    property int currentIndex: grid.currentIndex
    readonly property int count: grid.count
    readonly property var currentItem: {
        let model = root.ctx.activeModel;
        if (!model || grid.currentIndex < 0 || grid.currentIndex >= model.count) return null;
        return model.get(grid.currentIndex);
    }

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

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.ctx.s(20)
        spacing: root.ctx.s(20)

        // Collection sidebar.
        Rectangle {
            visible: root.ctx.showSidebar
            Layout.preferredWidth: root.ctx.s(220)
            Layout.fillHeight: true
            radius: root.ctx.s(16)
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                anchors.fill: parent
                anchors.margins: root.ctx.s(15)
                spacing: root.ctx.s(6)

                Text {
                    text: "Library"
                    color: root.theme.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(14)
                    font.bold: true
                }

                Repeater {
                    model: root.ctx.filterData
                    delegate: Rectangle {
                        required property var modelData
                        id: filterRow
                        visible: modelData.name !== "Search"
                        width: parent.width
                        height: root.ctx.s(44)
                        radius: Theme.radiusLg
                        color: root.ctx.currentFilter === modelData.name
                            ? Theme.surfaceContainerHigh
                            : (mouse.containsMouse ? Theme.surfaceContainer : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        readonly property bool isColor: String(modelData.hex || "") !== ""
                        readonly property string icon: modelData.name === "Video" ? "\uF03D"
                            : modelData.name === "Favorites" ? "\uF005"
                            : modelData.name === "All" ? "\uF00A" : ""

                        Rectangle {
                            id: iconSlot
                            anchors.left: parent.left
                            anchors.leftMargin: root.ctx.s(12)
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.ctx.s(24)
                            height: root.ctx.s(24)
                            radius: root.ctx.s(6)
                            color: filterRow.isColor
                                ? modelData.hex
                                : Theme.surfaceContainer
                            border.width: filterRow.isColor ? 0 : 1
                            border.color: Theme.outlineVariant

                            Text {
                                anchors.centerIn: parent
                                visible: !filterRow.isColor && filterRow.icon !== ""
                                text: filterRow.icon
                                color: root.ctx.currentFilter === modelData.name
                                    ? root.theme.text
                                    : root.theme.subtext0
                                font.family: "Hack Nerd Font"
                                font.pixelSize: root.ctx.s(14)
                            }
                        }

                        Text {
                            anchors.left: iconSlot.right
                            anchors.leftMargin: root.ctx.s(10)
                            anchors.right: parent.right
                            anchors.rightMargin: root.ctx.s(12)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name === "Favorites" ? "Favorites" : modelData.name
                            color: root.ctx.currentFilter === modelData.name
                                ? root.theme.text
                                : Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.68)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: root.ctx.s(13)
                            font.weight: root.ctx.currentFilter === modelData.name ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.ctx.currentFilter = modelData.name
                        }
                    }
                }
            }
        }

        // Thumbnail grid.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.ctx.s(14)
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.outlineVariant

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: root.ctx.s(10)
                cellWidth: Math.max(1, Math.floor(width / Math.max(2, Math.min(6, root.ctx.gridColumns))))
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

        // Inspector.
        Rectangle {
            visible: root.ctx.showInspector
            Layout.preferredWidth: root.ctx.s(300)
            Layout.fillHeight: true
            radius: root.ctx.s(16)
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                anchors.fill: parent
                anchors.margins: root.ctx.s(15)
                spacing: root.ctx.s(10)

                Rectangle {
                    width: parent.width
                    height: root.ctx.s(180)
                    radius: root.ctx.s(10)
                    clip: true
                    color: root.theme.base

                    Image {
                        anchors.fill: parent
                        source: root.currentItem
                            ? root.ctx.displaySource(String(root.currentItem.fileName), root.currentItem.fileUrl)
                            : ""
                        sourceSize: Qt.size(900, 600)
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                Text {
                    width: parent.width
                    text: root.currentItem
                        ? String(root.ctx.getCleanName(root.currentItem.fileName)).split("/").pop()
                        : "No selection"
                    color: root.theme.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(14)
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.ctx.showMetadata
                    text: root.currentItem
                        ? (String(root.currentItem.fileName).startsWith("scn_") ? "Interactive scene"
                           : String(root.currentItem.fileName).startsWith("000_") ? "Video"
                           : "Image")
                        : ""
                    color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.58)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(9)
                }

                Text {
                    width: parent.width
                    text: root.currentItem ? String(root.ctx.getCleanName(root.currentItem.fileName)) : ""
                    color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.45)
                    font.family: "Hack Nerd Font"
                    font.pixelSize: root.ctx.s(8)
                    elide: Text.ElideRight
                }

                Row {
                    spacing: root.ctx.s(6)

                    Rectangle {
                        width: root.ctx.s(96)
                        height: root.ctx.s(40)
                        radius: root.ctx.s(10)
                        color: root.theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            color: root.theme.crust
                            font.family: "Hack Nerd Font"
                            font.pixelSize: root.ctx.s(14)
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
                        width: root.ctx.s(40)
                        height: root.ctx.s(40)
                        radius: root.ctx.s(10)
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.outlineVariant
                        Text {
                            anchors.centerIn: parent
                            text: "\uF005"
                            color: root.currentItem && root.ctx.isFavorite(String(root.currentItem.fileName))
                                ? root.theme.mauve
                                : root.theme.text
                            font.family: "Hack Nerd Font"
                            font.pixelSize: root.ctx.s(12)
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
                }
            }
        }
    }
}
