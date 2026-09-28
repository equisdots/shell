import QtQuick

// ═══════════════════════════════════════════════════════════════════════════
// MascotDock — widget dock that unfolds out of the mascot island.
//
// Self-contained module file: no shell imports. The host toggles `open`, feeds
// the palette and the widget list; this component only draws and pages.
//
// Reveal: `target` (open ? 1 : 0) animates with a Behavior; `reveal` follows
// it. Background height, content opacity and content yScale all track
// `reveal`, so the panel unfolds from its top edge and retargets smoothly if
// `open` flips mid-animation.
//
// Layout: header (title + close) / strip with prev arrow, up to 3 cards, next
// arrow / page dots bottom-right. Clicking a card emits launchRequested(id);
// the host owns the actual launch. Clicking close emits closeRequested().
//
// API: open / widgets / palette / scaleUnit / accent / reveal / panelWidth /
//      panelHeight / launchRequested(string id) / closeRequested().
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: dock

    property bool open: false
    property var widgets: []
    property var palette: ({})
    property real scaleUnit: 0.78
    property color accent: "#cba6f7"

    signal launchRequested(string id)
    signal closeRequested()

    // Animation driver: bound to `open`, animated by the Behavior below.
    property real target: dock.open ? 1.0 : 0.0
    Behavior on target { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    readonly property real reveal: dock.target

    readonly property real panelWidth: dock.s(560)
    readonly property real panelHeight: dock.s(150)

    // ── Scaling ─────────────────────────────────────────────────────────────
    // Guarded so a missing/invalid scaleUnit still yields usable geometry.
    readonly property real effectiveScale: (dock.scaleUnit > 0 && dock.scaleUnit <= 10) ? dock.scaleUnit : 0.78
    function s(v) { return Math.round(v * dock.effectiveScale) }

    // ── Palette ─────────────────────────────────────────────────────────────
    // Catppuccin-Mocha fallbacks keep the dock usable while palette is empty.
    function pal(key, fallback) {
        const p = dock.palette;
        const v = (p && typeof p === "object") ? p[key] : undefined;
        return (v === undefined || v === null) ? fallback : v;
    }
    readonly property color cBase: dock.pal("base", "#1e1e2e")
    readonly property color cSurface1: dock.pal("surface1", "#45475a")
    readonly property color cText: dock.pal("text", "#cdd6f4")
    readonly property bool cGlassOn: !!dock.pal("glassOn", false)

    // Safe string access for widget entries with missing keys.
    function field(item, key) {
        const v = (item && typeof item === "object") ? item[key] : undefined;
        return (v === undefined || v === null) ? "" : v;
    }

    // ── Paging ──────────────────────────────────────────────────────────────
    readonly property int pageSize: 3
    readonly property var widgetList: (dock.widgets && dock.widgets.length !== undefined) ? dock.widgets : []
    readonly property int widgetCount: dock.widgetList.length
    readonly property int pageCount: Math.max(1, Math.ceil(dock.widgetCount / dock.pageSize))
    property int page: 0

    onPageChanged: dock.clampPage()
    onPageCountChanged: dock.clampPage()

    function clampPage() {
        const maxPage = dock.pageCount - 1;
        if (dock.page > maxPage) dock.page = maxPage;
        else if (dock.page < 0) dock.page = 0;
    }

    readonly property var pageItems: {
        const list = dock.widgetList;
        const start = dock.page * dock.pageSize;
        return list.slice(start, start + dock.pageSize);
    }

    readonly property bool canPrev: dock.page > 0
    readonly property bool canNext: dock.page < dock.pageCount - 1
    function prevPage() { if (dock.canPrev) dock.page -= 1 }
    function nextPage() { if (dock.canNext) dock.page += 1 }

    // ── Geometry constants (all through s) ──────────────────────────────────
    readonly property real sidePad: dock.s(10)
    readonly property real headerH: dock.s(22)
    readonly property real arrowW: dock.s(24)
    readonly property real arrowGap: dock.s(6)
    readonly property real cardGap: dock.s(8)
    // Three cards, two arrows and the gaps must fit inside panelWidth.
    readonly property real cardW: Math.floor(
        (dock.panelWidth - 2 * dock.sidePad - 2 * dock.arrowW - 2 * dock.arrowGap - 2 * dock.cardGap) / 3)

    implicitWidth: dock.panelWidth
    implicitHeight: dock.panelHeight
    clip: true

    // ── Background: unfolds downward from the top edge ───────────────────────
    Rectangle {
        id: bg
        width: dock.panelWidth
        height: Math.max(0, dock.panelHeight * dock.reveal)
        radius: dock.s(14)
        color: Qt.rgba(dock.cBase.r, dock.cBase.g, dock.cBase.b, dock.cGlassOn ? 0.9 : 1.0)
        border.width: 1
        border.color: Qt.alpha(dock.cSurface1, 0.9)
    }

    // ── Content: fixed layout, vertically unfolded by `reveal` ───────────────
    Item {
        id: content
        width: dock.panelWidth
        height: dock.panelHeight
        opacity: dock.reveal
        transform: Scale {
            origin.x: 0
            origin.y: 0
            yScale: dock.reveal
        }

        // ── Header ───────────────────────────────────────────────────────────
        Item {
            id: header
            anchors.top: parent.top
            anchors.topMargin: dock.s(8)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: dock.sidePad
            anchors.rightMargin: dock.sidePad
            height: dock.headerH

            Text {
                id: headerLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Widgets"
                font.family: "Hack Nerd Font"
                font.weight: Font.Bold
                font.pixelSize: dock.s(12)
                color: dock.cText
            }

            Rectangle {
                id: closeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: dock.s(20)
                height: dock.s(20)
                radius: dock.s(6)
                color: closeMa.containsMouse ? Qt.alpha(dock.cText, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0156"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: dock.s(14)
                    color: closeMa.containsMouse ? dock.accent : dock.cText
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.closeRequested()
                }
            }
        }

        // ── Card strip ───────────────────────────────────────────────────────
        Item {
            id: strip
            anchors.top: header.bottom
            anchors.topMargin: dock.s(4)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: dock.sidePad
            anchors.rightMargin: dock.sidePad
            anchors.bottom: dotsRow.top
            anchors.bottomMargin: dock.s(4)

            Row {
                id: cardRow
                x: dock.arrowW + dock.arrowGap
                height: parent.height
                spacing: dock.cardGap

                Repeater {
                    model: dock.pageItems
                    delegate: Rectangle {
                        id: card
                        required property int index
                        required property var modelData
                        width: dock.cardW
                        height: strip.height
                        radius: dock.s(10)
                        color: cardMa.containsMouse
                            ? Qt.alpha(dock.accent, 0.12)
                            : Qt.alpha(dock.cText, 0.05)
                        border.width: 1
                        border.color: cardMa.containsMouse
                            ? dock.accent
                            : Qt.alpha(dock.cSurface1, 0.8)
                        scale: cardMa.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - dock.s(12)
                            spacing: dock.s(6)

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: dock.field(card.modelData, "icon")
                                font.family: "Hack Nerd Font"
                                font.pixelSize: dock.s(24)
                                color: cardMa.containsMouse ? dock.accent : dock.cText
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: dock.field(card.modelData, "label")
                                elide: Text.ElideRight
                                font.family: "Hack Nerd Font"
                                font.pixelSize: dock.s(10)
                                color: dock.cText
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (card.modelData && card.modelData.id !== undefined)
                                    dock.launchRequested(String(card.modelData.id));
                            }
                        }
                    }
                }
            }

            // Prev arrow
            Rectangle {
                id: prevBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: dock.arrowW
                height: dock.arrowW
                radius: dock.s(8)
                color: (prevMa.containsMouse && dock.canPrev) ? Qt.alpha(dock.cText, 0.06) : "transparent"
                opacity: dock.canPrev ? (prevMa.containsMouse ? 1.0 : 0.8) : 0.35
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0141"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: dock.s(18)
                    color: dock.cText
                }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dock.canPrev ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: dock.prevPage()
                }
            }

            // Next arrow
            Rectangle {
                id: nextBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: dock.arrowW
                height: dock.arrowW
                radius: dock.s(8)
                color: (nextMa.containsMouse && dock.canNext) ? Qt.alpha(dock.cText, 0.06) : "transparent"
                opacity: dock.canNext ? (nextMa.containsMouse ? 1.0 : 0.8) : 0.35
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0142"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: dock.s(18)
                    color: dock.cText
                }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dock.canNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: dock.nextPage()
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: dock.widgetCount === 0
                text: "No widgets"
                font.family: "Hack Nerd Font"
                font.pixelSize: dock.s(12)
                color: Qt.alpha(dock.cText, 0.5)
            }
        }

        // ── Page dots (bottom-right, current page filled with accent) ────────
        Row {
            id: dotsRow
            anchors.right: parent.right
            anchors.rightMargin: dock.s(12)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: dock.s(6)
            spacing: dock.s(4)
            visible: dock.pageCount > 1

            Repeater {
                model: dock.pageCount
                delegate: Rectangle {
                    id: dot
                    required property int index
                    width: dock.s(5)
                    height: dock.s(5)
                    radius: Math.min(width, height) / 2
                    color: dot.index === dock.page ? dock.accent : Qt.alpha(dock.cText, 0.25)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.page = dot.index
                    }
                }
            }
        }
    }
}
