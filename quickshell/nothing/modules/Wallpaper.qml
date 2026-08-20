import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Wallpaper drawn by the shell - no need for swww or hyprpaper.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: Theme.c.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nothing-wallpaper"
    // Without this, the bar's exclusive zone crops the wallpaper and
    // lets the compositor background colour show at the top.
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}   // fully click-through

    Image {
        anchors.fill: parent
        source: Config.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        smooth: true
    }
}
