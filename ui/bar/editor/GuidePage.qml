import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../core"

// ═══════════════════════════════════════════════════════════════════════════
// GuidePage (About) — equisdots: brand header, live system + stack info
// (sysinfo.sh), timex/customization summary, action buttons and repo cards.
// Same card language as the Modules page; palette-driven.
// ═══════════════════════════════════════════════════════════════════════════
Item {
    id: root
    anchors.fill: parent
    property var bar: null
    property var info: ({})
    property int tick: 0
    property string doctorOut: ""
    property bool copiedFlash: false
    property string infoScript: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/ui/bar/popups/guide/sysinfo.sh"

    function val(key) {
        root.tick;
        let v = root.info[key];
        return (v !== undefined && v !== null && String(v).trim() !== "") ? String(v) : "—";
    }

    Process {
        id: sysinfoProc
        command: ["bash", root.infoScript]
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

    Process {
        id: doctorProc
        command: ["bash", "-c",
            "D=\"$HOME/.local/share/equisdots/dots/dots\"; " +
            "if [ -x \"$D\" ]; then bash \"$D\" doctor 2>&1; " +
            "else echo 'dots is not installed (run: dots system && dots install)'; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.doctorOut = this.text.trim() !== "" ? this.text.trim() : "no output"
        }
    }

    Timer { id: copiedTimer; interval: 1600; onTriggered: root.copiedFlash = false }

    // ── Summary strip (stack + customization, not duplicating the cards) ──
    readonly property var chips: [
        { k: "stack_ver", prefix: "equisdots " },
        { k: "hypr_ver", prefix: "Hyprland " },
        { k: "qs_ver", prefix: "Quickshell " },
        { k: "palette", prefix: "palette " },
        { k: "bar_engine", prefix: "bar " },
        { k: "timex_provider", prefix: "timex " }
    ]

    readonly property var sections: [
        { title: "System", role: "mauve", rows: [
            { k: "os", label: "OS" },
            { k: "host", label: "Host" },
            { k: "kernel", label: "Kernel" },
            { k: "uptime", label: "Uptime" },
            { k: "boot", label: "Boot" }
        ] },
        { title: "Session", role: "blue", rows: [
            { k: "user", label: "User" },
            { k: "shell", label: "Shell" },
            { k: "iface", label: "Interface" },
            { k: "ip", label: "IP" },
            { k: "ssid", label: "SSID" }
        ] },
        { title: "Hardware", role: "green", rows: [
            { k: "cpu", label: "CPU" },
            { k: "gpu", label: "GPU" },
            { k: "memory", label: "Memory" },
            { k: "disk", label: "Disk" },
            { k: "battery", label: "Battery" }
        ] },
        { title: "Display", role: "peach", rows: [
            { k: "res", label: "Resolution" },
            { k: "refresh", label: "Refresh" },
            { k: "monitors", label: "Monitors" },
            { k: "scale", label: "Scale" }
        ] },
        { title: "Timex", role: "yellow", rows: [
            { k: "timex_provider", label: "Provider" },
            { k: "timex_city", label: "City" },
            { k: "timex_unit", label: "Unit" },
            { k: "timex_updated", label: "Updated" },
            { k: "timex_error", label: "Error", opt: true }
        ] },
        { title: "Customization", role: "pink", rows: [
            { k: "palette", label: "Palette" },
            { k: "bar_engine", label: "Bar engine" },
            { k: "gtk_theme", label: "GTK theme" },
            { k: "stack_date", label: "Stack date" }
        ] }
    ]

    readonly property var repos: [
        { label: "shell", icon: "󰍜", role: "mauve", url: "https://github.com/equisdots/shell" },
        { label: "hyprland", icon: "󰣇", role: "blue", url: "https://github.com/equisdots/hyprland" },
        { label: "timex", icon: "󰖐", role: "yellow", url: "https://github.com/equisdots/timex" },
        { label: "dots", icon: "󰒓", role: "green", url: "https://github.com/equisdots/dots" },
        { label: "palettes", icon: "✦", role: "peach", url: "https://github.com/equisdots/palettes" },
        { label: "davincix", icon: "󰹑", role: "teal", url: "https://github.com/equisdots/davincix" },
        { label: "theme-sync", icon: "󰏘", role: "pink", url: "https://github.com/equisdots/theme-sync" }
    ]

    // Small pill button used by the action row.
    component ActionChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        signal clicked()
        height: root.bar.s(30)
        radius: root.bar.s(15)
        width: chipRow.implicitWidth + root.bar.s(26)
        color: chipMa.containsMouse ? Qt.alpha(root.bar.colors.mauve, 0.16) : Qt.alpha(root.bar.colors.surface0, 0.5)
        border.width: 1
        border.color: chipMa.containsMouse ? root.bar.colors.mauve : root.bar.colors.surface1
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: root.bar.s(7)
            Text {
                text: chip.icon
                font.family: "Hack Nerd Font"; font.pixelSize: root.bar.s(13)
                color: chipMa.containsMouse ? root.bar.colors.mauve : root.bar.colors.subtext0
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.label
                font.family: "Hack Nerd Font"; font.pixelSize: root.bar.s(11)
                color: root.bar.colors.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
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

                    // ── Brand header ───────────────────────────────────────
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
                            text: "shell · hyprland · timex · palettes · davincix · theme-sync"
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
                                        text: modelData.prefix + root.val(modelData.k)
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(12)
                                        color: bar.colors.subtext0
                                    }
                                }
                            }
                        }
                    }

                    // ── Action row ─────────────────────────────────────────
                    Flow {
                        width: parent.width
                        spacing: bar.s(8)
                        ActionChip {
                            icon: "󰆏"; label: root.copiedFlash ? "Copied!" : "Copy debug info"
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "bash '" + root.infoScript + "' | wl-copy"]);
                                root.copiedFlash = true;
                                copiedTimer.restart();
                            }
                        }
                        ActionChip {
                            icon: "󰒓"; label: "Run doctor"
                            onClicked: { root.doctorOut = "Running…"; doctorProc.running = false; doctorProc.running = true; }
                        }
                        ActionChip {
                            icon: "󰚰"; label: "Updates"
                            onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "updater"])
                        }
                        ActionChip {
                            icon: "󰈙"; label: "Docs"
                            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/equisdots"])
                        }
                        ActionChip {
                            icon: "󰈂"; label: "Report issue"
                            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/equisdots/shell/issues/new"])
                        }
                    }

                    // ── Doctor output ──────────────────────────────────────
                    Rectangle {
                        width: parent.width
                        visible: root.doctorOut !== ""
                        height: visible ? doctorCol.implicitHeight + bar.s(34) : 0
                        radius: bar.s(18)
                        color: Qt.alpha(bar.colors.surface0, 0.4)
                        border.width: 1
                        border.color: bar.colors.surface1
                        Column {
                            id: doctorCol
                            x: bar.s(18); y: bar.s(14)
                            width: parent.width - bar.s(60)
                            spacing: bar.s(8)
                            Text {
                                text: "dots doctor"
                                font.family: "Hack Nerd Font"; font.weight: Font.Black; font.pixelSize: bar.s(14)
                                color: bar.colors.green
                            }
                            Text {
                                width: parent.width
                                text: root.doctorOut
                                font.family: "Hack Nerd Font"; font.pixelSize: bar.s(11)
                                color: bar.colors.subtext0
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                        MouseArea {
                            anchors.right: parent.right; anchors.top: parent.top
                            width: bar.s(30); height: bar.s(30)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.doctorOut = ""
                            Text {
                                anchors.centerIn: parent; text: "󰅖"
                                font.family: "Hack Nerd Font"; font.pixelSize: bar.s(14)
                                color: bar.colors.subtext0
                            }
                        }
                    }

                    // ── Sections (grid 2 columnas, alto por contenido) ─────
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
                                implicitHeight: secCol.implicitHeight + bar.s(34)
                                height: implicitHeight
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
                                            visible: !modelData.opt || root.val(modelData.k) !== "—"
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
                                                text: root.val(modelData.k)
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
                                readonly property string rev: (root.tick, root.info["repo_" + modelData.label] || "")
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
                                        text: repoCard.rev !== "" ? repoCard.rev : "not installed via dots"
                                        font.family: "Hack Nerd Font"
                                        font.pixelSize: bar.s(11)
                                        color: repoCard.rev !== "" ? bar.colors.subtext0 : Qt.alpha(bar.colors.subtext0, 0.6)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: "equisdots/" + repoCard.modelData.label
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

                    // ── Footer (licencia + créditos) ───────────────────────
                    Text {
                        topPadding: bar.s(10)
                        bottomPadding: bar.s(6)
                        width: parent.width
                        text: "MIT licensed · built with Quickshell · wallpaper daemon: xwww (fork of awww) · base16 palettes"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: bar.s(11)
                        color: Qt.alpha(bar.colors.subtext0, 0.8)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
