import QtQuick
import "../../../../../core"

// ---------------------------------------------------------------------------
// DavinciRow - dense result row used by the palette view mode. It preserves
// the same file-name conventions as DavinciCard/DavinciTile and never applies
// a wallpaper by itself; the owning view decides that.
// ---------------------------------------------------------------------------
Rectangle {
    id: row

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

    height: ctx.s(56)
    radius: ctx.s(9)
    color: selected
        ? Theme.surfaceContainerHigh
        : (mouse.containsMouse ? Theme.surfaceContainer : "transparent")
    border.width: selected ? 1 : 0
    border.color: Theme.outlineVariant

    Row {
        anchors.fill: parent
        anchors.margins: ctx.s(6)
        spacing: ctx.s(10)

        Rectangle {
            width: ctx.s(70)
            height: parent.height
            radius: ctx.s(6)
            clip: true
            color: theme.base

            Image {
                anchors.fill: parent
                source: row.fileUrl
                sourceSize: Qt.size(320, 200)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }

        Column {
            width: parent.width - ctx.s(70) - ctx.s(10) - ctx.s(30)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ctx.s(2)

            Text {
                width: parent.width
                text: row.cleanName
                color: theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(11)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: ctx.showMetadata
                text: row.isScene ? "Interactive scene"
                    : row.isVideo ? "Video"
                    : "Image"
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.55)
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(9)
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: row.isVideo || row.isScene
            width: badgeText.implicitWidth + ctx.s(12)
            height: ctx.s(20)
            radius: ctx.s(6)
            anchors.verticalCenter: parent.verticalCenter
            color: row.isScene
                ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.85)
                : Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.68)
            border.width: 1
            border.color: Theme.outlineVariant

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: row.isScene ? "SCENE" : "VIDEO"
                color: row.isScene ? theme.crust : theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(8)
                font.bold: true
            }
        }

        Rectangle {
            z: 20
            visible: row.selected || row.isFavorite || mouse.containsMouse
            width: ctx.s(24)
            height: ctx.s(24)
            radius: ctx.s(6)
            anchors.verticalCenter: parent.verticalCenter
            color: row.isFavorite
                ? Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.9)
                : Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.55)
            border.width: 1
            border.color: Theme.outlineVariant

            Text {
                anchors.centerIn: parent
                text: "\uF005"
                color: row.isFavorite ? theme.crust : theme.text
                font.family: "Hack Nerd Font"
                font.pixelSize: ctx.s(12)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.favoriteToggled()
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
