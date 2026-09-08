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

    // Read only, from the caller's point of view: every user of this
    // component binds `open` to a flag in GlobalState, and assigning to a
    // bound property destroys the binding. That is what happened here for
    // months. Clicking the scrim assigned false to it, the binding to
    // GlobalState.notifCenterOpen was gone from that moment on, and the
    // notification centre could never be opened again for the life of the
    // shell: the flag went true and the window no longer followed it.
    //
    // So the panel asks to be closed and the owner of the flag does it,
    // the way the control centre already did. The flag stays the one place
    // the answer lives.
    property bool open: false
    signal closeRequested()
    function requestClose(): void { win.closeRequested(); }

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
        MouseArea { anchors.fill: parent; onClicked: win.requestClose() }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.requestClose()
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
