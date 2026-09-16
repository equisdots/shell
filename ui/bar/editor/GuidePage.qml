import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// GuidePage (About) — equisdots: brand header, system information from the
// machine itself (sysinfo.sh) in uniform cards, and repo cards. Same card
// language as the Modules page; palette-driven.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent
    property var bar: null
    property var info: ({})
    property int tick: 0

    Process {
        id: sysinfoProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/ui/bar/popups/guide/sysinfo.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = {};
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let p = lines[i].indexOf("=");
                    if (p > 0) out[lines[i].substring(0, p)] = lines[i].substring(p + 1);
                }
                root.info = out;
                root.tick++;
            }
        }
    }

    readonly property var sections: [
        { title: "System", role: "mauve", rows: [
            { k: "os", label: "OS" },
            { k: "host", label: "Host" },
            { k: "kernel", label: "Kernel" },
            { k: "wm", label: "WM" }
        ] },
        { title: "Session", role: "blue", rows: [
            { k: "user", label: "User" },
            { k: "shell", label: "Shell" },
            { k: "uptime", label: "Uptime" }
        ] },
        { title: "Hardware", role: "green", rows: [
            { k: "cpu", label: "CPU" },
            { k: "gpu", label: "GPU" },
            { k: "memory", label: "Memory" },
            { k: "disk", label: "Disk" }
        ] },
        { title: "Display", role: "peach", rows: [
            { k: "res", label: "Resolution" },
            { k: "refresh", label: "Refresh" },
            { k: "monitors", label: "Monitors" },
            { k: "scale", label: "Scale" }
        ] }
    ]

    readonly property var chips: [
        { k: "os", label: "OS" },
        { k: "host", label: "Host" },
        { k: "kernel", label: "Kernel" },
        { k: "wm", label: "WM" },
        { k: "cpu", label: "CPU" }
    ]

    readonly property var repos: [
        { label: "shell", icon: "󰍜", role: "mauve", url: "https://github.com/equisdots/shell" },
        { label: "hyprland", icon: "󰣇", role: "blue", url: "https://github.com/equisdots/hyprland" },
        { label: "dots", icon: "󰒓", role: "green", url: "https://github.com/equisdots/dots" },
        { label: "palettes", icon: "✦", role: "peach", url: "https://github.com/equisdots/palettes" },
        { label: "davincix", icon: "󰹑", role: "teal", url: "https://github.com/equisdots/davincix" },
        { label: "theme-sync", icon: "󰏘", role: "pink", url: "https://github.com/equisdots/theme-sync" }
    ]

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
                contentHeight: pageCol.height + bar.s(16)
                ScrollBar.vertical: ScrollBar {
                    width: bar.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: bar.s(2); color: bar.colors.surface2; opacity: parent.active ? 1 : 0.45 }
                    background: Item {}
                }

                Column {
                    id: pageCol
                    x: bar.s(8); y: bar.s(8)
                    width: pageFlick.width - bar.s(16)
                    spacing: bar.s(14)

                    // ── Brand header (apilado: sin solapes posibles) ───────
                    Column {
                        width: parent.width
                        spacing: bar.s(10)
                        topPadding: bar.s(4)
                        Row {
                            spacing: bar.s(7)
                            Rectangle { width: bar.s(10); height: bar.s(10); radius: bar.s(5); color: bar.colors.mauve }
                            Rectangle { width: bar.s(10); height: bar.s(10); radius: bar.s(5); color: bar.colors.blue }
                            Rectangle { width: bar.s(10); height: bar.s(10); radius: bar.s(5); color: bar.colors.green }
                        }
                        Row {
                            spacing: 0
                            Text {
                                text: "equis"
                                font.family: "Hack Nerd Font"
                                font.weight: Font.Black
                                font.pixelSize: bar.s(42)
                                color: bar.colors.text
                            }
                            Text {
                                text: "dots"
                                font.family: "Hack Nerd Font"
                                font.weight: Font.Black
                                font.pixelSize: bar.s(42)
                                color: bar.colors.mauve
                            }
                        }
                        Text {
                            text: "shell · hyprland · palettes · davincix · theme-sync"
                            font.family: "Hack Nerd Font"
                            font.pixelSize: bar.s(13)
                            color: bar.colors.subtext0
                        }
                        Flow {
                            width: parent.width
                            spacing: bar.s(8)
                            Repeater {
                                model: root.chips
                                delegate: Rectangle {
                                    required property var modelData
                                    height: bar.s(32)
                                    radius: bar.s(16)
                                    width: chipText.implicitWidth + bar.s(26)
                                    color: Qt.alpha(bar.colors.surface0, 0.5)
                                    border.width: 1
                                    border.color: bar.colors.surface1
                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData.label + ": " + (root.info[modelData.k] || "…")
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                    }
                                }
                            }
                        }
                    }

                    // ── Secciones (grid 2 columnas, estilo Modules) ────────
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: bar.s(12)
                        rowSpacing: bar.s(12)
                        Repeater {
                            model: root.sections
                            delegate: Rectangle {
                                id: secCard
                                required property var modelData
                                readonly property color accent: bar.colors[modelData.role] || bar.colors.mauve
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                radius: bar.s(18)
                                color: Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1
                                border.color: bar.colors.surface1
                                height: bar.s(184)
                                Column {
                                    id: secCol
                                    x: bar.s(22); y: bar.s(17)
                                    width: parent.width - bar.s(38)
                                    spacing: bar.s(9)
                                    Row {
                                        spacing: bar.s(8)
                                        Rectangle {
                                            width: bar.s(9); height: bar.s(9); radius: bar.s(2)
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: secCard.accent
                                        }
                                        Text {
                                            text: secCard.modelData.title
                                            font.family: "Hack Nerd Font"
                                            font.weight: Font.Black
                                            font.pixelSize: bar.s(16)
                                            color: secCard.accent
                                        }
                                    }
                                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(secCard.accent, 0.35) }
                                    Repeater {
                                        model: secCard.modelData.rows
                                        delegate: Row {
                                            required property var modelData
                                            width: secCol.width
                                            spacing: bar.s(10)
                                            Text {
                                                width: bar.s(78)
                                                text: modelData.label
                                                font.family: "Hack Nerd Font"
                                                font.weight: Font.Bold
                                                font.pixelSize: bar.s(13)
                                                color: bar.colors.subtext0
                                                topPadding: bar.s(1)
                                            }
                                            Text {
                                                width: secCol.width - bar.s(88)
                                                text: (root.tick, root.info[modelData.k] || "…")
                                                font.family: "Hack Nerd Font"
                                                font.pixelSize: bar.s(13)
                                                color: bar.colors.text
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Repositorios (grid 3 columnas, ancho completo) ────
                    Text {
                        topPadding: bar.s(14)
                        text: "Repositories"
                        font.family: "Hack Nerd Font"
                        font.weight: Font.Black
                        font.pixelSize: bar.s(16)
                        color: bar.colors.text
                    }
                    GridLayout {
                        width: parent.width
                        columns: 3
                        columnSpacing: bar.s(12)
                        rowSpacing: bar.s(12)
                        Repeater {
                            model: root.repos
                            delegate: Rectangle {
                                id: repoCard
                                required property var modelData
                                readonly property color accent: bar.colors[modelData.role] || bar.colors.mauve
                                Layout.fillWidth: true
                                height: bar.s(80)
                                radius: bar.s(16)
                                color: repoHover.containsMouse ? Qt.alpha(accent, 0.16) : Qt.alpha(bar.colors.surface0, 0.4)
                                border.width: 1
                                border.color: repoHover.containsMouse ? accent : bar.colors.surface1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Rectangle {
                                    width: bar.s(42); height: bar.s(42); radius: bar.s(12)
                                    anchors.left: parent.left
                                    anchors.leftMargin: bar.s(12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.alpha(repoCard.accent, 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: repoCard.modelData.icon
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(20)
                                        color: repoCard.accent
                                    }
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: bar.s(64)
                                    anchors.right: parent.right
                                    anchors.rightMargin: bar.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: bar.s(2)
                                    Text {
                                        width: parent.width
                                        text: "equisdots/" + repoCard.modelData.label
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: repoCard.modelData.label
                                        font.family: "Hack Nerd Font"
                                        font.weight: Font.Black
                                        font.pixelSize: bar.s(16)
                                        color: bar.colors.text
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    id: repoHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", repoCard.modelData.url])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
