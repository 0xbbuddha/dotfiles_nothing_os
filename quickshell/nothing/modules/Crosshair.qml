import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

// Crosshair drawn by the shell, screen centre, click-through.
// The stroke lives in CrosshairArt, shared with the settings preview.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    visible: Config.crosshair
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-crosshair"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Empty region: the crosshair must never intercept the mouse.
    mask: Region {}

    CrosshairArt {
        anchors.centerIn: parent
    }
}
