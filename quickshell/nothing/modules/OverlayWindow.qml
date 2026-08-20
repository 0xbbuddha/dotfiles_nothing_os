import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../components"

// Shared base for fullscreen panels (launcher, clipboard, notification
// centre, preview). Handles the scrim, outside click, Escape and the
// open animation; content goes in `sheet`.
PanelWindow {
    id: win
    required property var modelData

    property bool open: false
    property alias sheetWidth: card.width
    property alias sheetHeight: card.height
    property real topBias: 0.5          // 0.5 = vertically centred
    default property alias content: card.data

    // 'opened' and 'closed' already exist on Window: other names are required.
    signal shown()
    signal hidden()

    screen: modelData
    color: "transparent"

    // The panel is created on every screen but only shown on the one
    // you are working on, rather than always on the primary.
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    visible: open && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-overlay"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    onVisibleChanged: visible ? win.shown() : win.hidden()

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.open = false
    }

    NCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) * win.topBias
        width: Theme.z.sheet
        height: Math.min(Theme.px(430), parent.height * 0.7)
        clip: true

        scale: win.open ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
    }
}
