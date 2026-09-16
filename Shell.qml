//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./ui"
import "./ui/bar"
import "./ui/widgets"

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main {}
    Bar {}
    Floating {}
    Widgets {}
}
