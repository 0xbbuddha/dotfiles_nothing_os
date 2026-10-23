import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// A card sliding down to say the wallpaper changed, then sliding back
// up on its own - the same shape ReloadPopup uses for "the shell has
// something to tell you right now", just for news instead of a fault.
PanelWindow {
    id: win
    required property var modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    screen: modelData
    color: "transparent"
    visible: WallpaperAnnounce.shown && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-wallpaper-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: card.implicitHeight + Theme.px(28)
    exclusionMode: ExclusionMode.Ignore
    // News, not a dialog: nothing here is worth a click, so nothing
    // here takes one.
    mask: Region {}

    NCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(14)
        implicitWidth: row.implicitWidth + Theme.pad * 2
        implicitHeight: row.implicitHeight + Theme.px(20)

        y: win.visible ? 0 : -Theme.px(24)
        opacity: win.visible ? 1 : 0
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(10)

            Rectangle {
                Layout.preferredWidth: Theme.px(34)
                Layout.preferredHeight: Theme.px(34)
                radius: Theme.r.tiny
                color: Theme.c.surface2
                clip: true

                Image {
                    anchors.fill: parent
                    source: WallpaperAnnounce.thumb !== ""
                        ? "file://" + WallpaperAnnounce.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                }
            }

            ColumnLayout {
                spacing: 0

                NLabel { text: "Wallpaper" }
                NText {
                    text: WallpaperAnnounce.label
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
