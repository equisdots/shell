import QtQuick
import Quickshell

// Prism glass — refractive edge lens used by the Prism appearance mode.
// It shares the wallpaper texture path with LiquidGlass but uses its own shader
// and parameters (stronger edge bending, chromatic separation, Fresnel rim).
ShaderEffect {
    id: root

    property variant src
    property vector2d itemSize: Qt.vector2d(width, height)
    property vector2d screenPos: Qt.vector2d(0, 0)
    property vector2d screenSize: Qt.vector2d(1, 1)
    property vector4d radii: Qt.vector4d(0, 0, 0, 0)
    property color tintColor: "#101018"
    property real bezel: 14
    property real thickness: 18
    property real ior: 1.48
    property real dispersion: 0.045
    property real frost: 10
    property real rim: 0.75
    property real tintAmount: 0.20
    property real interiorShade: 0.20
    property real saturation: 1.10
    property real fresnel: 0.55
    property real grain: 0.012
    property real facetStrength: 1.0
    property real sheenStrength: 1.0
    property vector4d sourceRect: Qt.vector4d(0, 0, 1, 1)
    property vector4d rimSides: Qt.vector4d(1, 1, 1, 1)

    fragmentShader: Qt.resolvedUrl("shaders/prism_glass.frag.qsb")
}
