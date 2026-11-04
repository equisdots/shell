import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================================
// LiquidGlass — original, MIT-licensed edge-lens glass for the shell.
//
// The compositor blur only frosts what is behind a surface. This component
// samples the current wallpaper snapshot instead and bends it at the surface
// edge with a small refraction, then adds a tint, a specular rim and grain.
// It is an approximation of Apple's Liquid Glass, not a copy of it.
//
// The wallpaper is the file davinci already writes (or glass-sync refreshes
// from xwww):
//   $XDG_CACHE_HOME/quickshell/wallpaper_picker/current_wallpaper.png
// The shader is `shaders/liquid_glass.frag.qsb`; it samples the wallpaper at
// the surface's screen coordinates so the glass lines up with the desktop.
// ============================================================================

Item {
    id: root

    property color tintColor: "#FF1A1B26"
    property real tintAmount: 0.16
    property real frost: 10
    property real interiorShade: 0.0
    property real thickness: 18
    property vector4d sourceRect: Qt.vector4d(0, 0, 1, 1)
    property real rim: 0.55
    property real ior: 1.45
    property real dispersion: 0.02
    property real grain: 0.02
    property real bezel: 14
    // Left, top, right, bottom rim weights. Full-bleed surfaces set the side
    // weights to 0 so the lens edge does not glow against the monitor bezel.
    property vector4d rimSides: Qt.vector4d(1, 1, 1, 1)

    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0

    readonly property var win: QsWindow.window
    readonly property var scr: win ? win.screen : null
    readonly property real winX: {
        if (!win || !win.anchors) return 0;
        const a = win.anchors, m = win.margins, sw = scr ? scr.width : 0;
        if (a.left) return m.left;
        if (a.right) return Math.max(0, sw - win.width - m.right);
        return Math.max(0, (sw - win.width) / 2);
    }
    readonly property real winY: {
        if (!win || !win.anchors) return 0;
        const a = win.anchors, m = win.margins, sh = scr ? scr.height : 0;
        if (a.top) return m.top;
        if (a.bottom) return Math.max(0, sh - win.height - m.bottom);
        return Math.max(0, (sh - win.height) / 2);
    }
    readonly property point local: {
        if (!win || !win.contentItem) return Qt.point(0, 0);
        return root.mapToItem(win.contentItem, 0, 0);
    }
    // Nested lenses (a popup card inside the master window) do not map cleanly
    // through win.contentItem; callers can pass scene/screen coordinates.
    property vector2d screenPosOverride: Qt.vector2d(-1, -1)
    readonly property vector2d screenPos: root.screenPosOverride.x >= 0
        ? root.screenPosOverride
        : Qt.vector2d(root.winX + root.local.x, root.winY + root.local.y)
    readonly property vector2d screenSize: Qt.vector2d(
        root.scr ? Math.max(1, root.scr.width) : Math.max(1, root.width),
        root.scr ? Math.max(1, root.scr.height) : Math.max(1, root.height))

    // Floating widgets only get the lens when they sit near the screen center;
    // edge widgets keep their compact solid face so they never compete with
    // the wallpaper composition.
    property bool enabled: true
    property bool centeredOnly: false
    property real centerTolerance: 0.28
    readonly property bool centered: {
        const cx = root.screenPos.x + root.width / 2;
        const cy = root.screenPos.y + root.height / 2;
        return Math.abs(cx - root.screenSize.x / 2) <= root.screenSize.x * root.centerTolerance
            && Math.abs(cy - root.screenSize.y / 2) <= root.screenSize.y * root.centerTolerance;
    }

    readonly property string cacheRoot: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string fallbackWallpaperPath: cacheRoot + "/quickshell/wallpaper_picker/current_wallpaper.png"
    readonly property string screenName: root.scr && root.scr.name ? root.scr.name : "default"
    readonly property string wallpaperPath: {
        const captured = Theme.auroraGlass && GlassBackdrop.hasCapture(root.screenName);
        return captured ? GlassBackdrop.sourceFor(root.screenName) : root.fallbackWallpaperPath;
    }
    property int wallpaperRev: 0
    readonly property bool ready: wallpaper.status === Image.Ready

    // glass-sync: the wallpaper snapshot is rewritten when the wallpaper
    // changes. GlassBackdrop also revises the shell-free desktop capture for
    // Aurora; either change must make the Image reload.
    // davinci/glass-sync replace the snapshot with tmp+mv, but the watcher can
    // still fire while an external writer is mid-write. Debounce the revision so
    // QML does not try to decode a partial PNG and log Image errors.
    FileView {
        path: root.fallbackWallpaperPath
        watchChanges: true
        onFileChanged: wallpaperDebounce.restart()
    }
    Timer {
        id: wallpaperDebounce
        interval: 180
        onTriggered: root.wallpaperRev++
    }

    visible: enabled && ready && width > 0 && height > 0 && (!centeredOnly || centered)

    Image {
        id: wallpaper
        width: root.screenSize.x
        height: root.screenSize.y
        fillMode: Image.PreserveAspectCrop
        source: "file://" + root.wallpaperPath + "?rev=" + root.wallpaperRev + "&cap=" + GlassBackdrop.revision
        sourceSize: Qt.size(
            Math.max(1, Math.round(root.screenSize.x / 2)),
            Math.max(1, Math.round(root.screenSize.y / 2)))
        cache: true
        asynchronous: true
        visible: !Theme.auroraGlass
        onStatusChanged: if (status === Image.Ready) texture.scheduleUpdate()
    }

    ShaderEffectSource {
        id: texture
        sourceItem: wallpaper
        hideSource: true
        live: false
        textureSize: Qt.size(
            Math.max(1, Math.round(root.screenSize.x / 2)),
            Math.max(1, Math.round(root.screenSize.y / 2)))
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.visible && !Theme.prismGlass && !Theme.auroraGlass

        property variant src: texture
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d screenPos: root.screenPos
        property vector2d screenSize: root.screenSize
        property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        property color tintColor: root.tintColor
        property real bezel: root.bezel
        property real ior: root.ior
        property real dispersion: root.dispersion
        property real frost: root.frost
        property real rim: root.rim
        property real tintAmount: root.tintAmount
        property real interiorShade: root.interiorShade
        property real grain: root.grain
        property vector4d rimSides: root.rimSides

        fragmentShader: Qt.resolvedUrl("shaders/liquid_glass.frag.qsb")
    }

    PrismGlass {
        anchors.fill: parent
        visible: root.visible && Theme.prismGlass && !Theme.auroraGlass
        src: texture
        itemSize: Qt.vector2d(root.width, root.height)
        screenPos: root.screenPos
        screenSize: root.screenSize
        radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        bezel: root.bezel
        ior: root.ior
        rim: root.rim
        tintColor: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, 1.0)
        tintAmount: root.tintAmount * Theme.prismTint
        interiorShade: root.interiorShade * Theme.prismShade
        dispersion: 0.16
        saturation: 1.12
        fresnel: 0.82
        frost: root.frost * Theme.prismBlur
        thickness: root.thickness * 1.65
        grain: root.grain
        facetStrength: Theme.prismIntensity
        sheenStrength: Theme.prismBrightness
        sourceRect: root.sourceRect
        rimSides: root.rimSides
    }

    // Aurora: a layered sibling of Prism. It uses an independent shader copy
    // (Prism itself is untouched), keeps the shader's rounded-corner geometry,
    // disables the hard Fresnel/rim, and lets the Aurora shader add its soft
    // top light band. No QML edge rectangles means no lines cutting through
    // nested surfaces.
    AuroraGlass {
        anchors.fill: parent
        visible: root.visible && Theme.auroraGlass
        src: texture
        itemSize: Qt.vector2d(root.width, root.height)
        screenPos: root.screenPos
        screenSize: root.screenSize
        radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        bezel: root.bezel
        ior: root.ior
        rim: 0.0
        tintColor: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, 1.0)
        tintAmount: root.tintAmount * Theme.auroraTint
        interiorShade: root.interiorShade * 0.85
        dispersion: 0.12
        saturation: 0.96
        fresnel: 0.0
        frost: root.frost * 1.35
        thickness: root.thickness * 1.35
        grain: root.grain
        facetStrength: 0.28
        sheenStrength: Theme.auroraSheen
        sourceRect: root.sourceRect
        rimSides: root.rimSides
    }

}
