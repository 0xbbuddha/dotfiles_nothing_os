import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// One veil per screen, on top of everything else, swept away left to
// right the instant the shell starts. Everything underneath is already
// in its place and fully drawn - Bar, Dock, the widgets - this only
// decides when each part of the screen is allowed to be seen. The one
// moment here with no natural entrance of its own is the desktop simply
// existing, so the reveal has to come from outside it rather than from
// any one surface.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-boot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    // Shrinks with the veil itself: the strip already swept past stops
    // taking clicks as it goes, rather than the whole screen staying
    // blocked until the last pixel is uncovered.
    mask: Region { item: veil }

    Rectangle {
        id: veil
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width
        color: Theme.c.surface
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 80 }
        NumberAnimation {
            target: veil
            property: "width"
            to: 0
            duration: 650
            easing.type: Theme.ease
        }
    }

    // However the sweep above might fail, the desktop must not stay
    // hidden behind it: a stuck veil is a far worse bug than a missing
    // animation.
    Timer {
        interval: 3000
        running: true
        onTriggered: veil.width = 0
    }
}
