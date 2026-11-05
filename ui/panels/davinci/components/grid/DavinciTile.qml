import QtQuick
import "../../../../../core"

// ---------------------------------------------------------------------------
// DavinciTile - compact wallpaper tile shared by the grid, library and stage
// view modes. It is intentionally read-only: the owning view decides what
// "activate" means (apply, focus, preview) and the picker root owns the model.
//
// Compatible file-name conventions (unchanged from the cover-flow card):
//   scn_<name>.jpg   interactive xwww scene
//   000_<name>       video poster
//   a__b.jpg         flattened nested path
// ---------------------------------------------------------------------------
Item {
    id: tile

    required property var ctx
    required property var theme
    required property string fileName
    required property url fileUrl
    required property int index
    property bool selected: false

    signal activated()
    signal favoriteToggled()

    readonly property bool isVideo: String(fileName).startsWith("000_")
    readonly property bool isScene: String(fileName).startsWith("scn_")
    readonly property bool isFavorite: ctx.isFavorite(String(fileName))
    readonly property string cleanName: {
        let n = String(ctx.getCleanName(fileName) || "");
        let parts = n.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : n;
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: ctx.s(12)
        clip: true
        color: theme.base
        border.width: tile.selected ? ctx.s(2) : 1
        border.color: tile.selected ? theme.text : Theme.outlineVariant

        Image {
            anchors.fill: parent
            source: tile.fileUrl
            sourceSize: Qt.size(960, 720)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.68) }
            }
        }

        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: ctx.s(8)
            spacing: ctx.s(6)

            Rectangle {
                visible: tile.isVideo || tile.isScene
                width: typeText.implicitWidth + ctx.s(12)
                height: ctx.s(20)
                radius: ctx.s(6)
                color: tile.isScene
                    ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.85)
                    : Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.68)
                border.width: 1
                border.color: Theme.outlineVariant

                Text {
                    id: typeText
                    anchors.centerIn: parent
                    text: tile.isScene ? "SCENE" : "VIDEO"
                    color: tile.isScene ? theme.crust : theme.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: ctx.s(8)
                    font.bold: true
                }
            }
        }

        Rectangle {
            id: favoriteButton
            z: 20
            visible: tile.selected || tile.isFavorite || mouse.containsMouse
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: ctx.s(8)
            width: ctx.s(24)
            height: ctx.s(24)
            radius: ctx.s(6)
            color: tile.isFavorite
                ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.9)
                : Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.55)
            border.width: 1
            border.color: Theme.outlineVariant

            Text {
                anchors.centerIn: parent
                text: "\uF005"
                color: tile.isFavorite ? theme.crust : theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(12)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.favoriteToggled()
            }
        }

        Column {
            visible: ctx.showMetadata
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: ctx.s(10)
            spacing: ctx.s(2)

            Text {
                width: parent.width
                text: tile.cleanName
                color: theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(11)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.isScene ? "interactive scene"
                    : tile.isVideo ? "video"
                    : "image"
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.62)
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(9)
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }
    }
}
