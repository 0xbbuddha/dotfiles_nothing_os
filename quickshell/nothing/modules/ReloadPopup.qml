import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The one panel that has to work when everything else might not: a
// reload that failed is exactly the moment a broken QML file could take
// the rest of the shell down with it, so this stays as small and as
// independent of the rest of the tree as the message it shows.
PanelWindow {
    id: win
    required property var modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    screen: modelData
    color: "transparent"
    visible: ReloadWatch.shown && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-reload-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: card.implicitHeight + Theme.px(28)
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: card }

    NCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(14)
        width: Math.min(Theme.px(560), win.width - Theme.px(32))
        implicitHeight: col.implicitHeight + Theme.pad * 2
        border.width: 1
        border.color: Theme.c.red

        y: win.visible ? 0 : -Theme.px(24)
        opacity: win.visible ? 1 : 0
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                Rectangle {
                    width: Theme.px(6); height: width; radius: width / 2
                    color: Theme.c.red
                }

                NText {
                    Layout.fillWidth: true
                    text: "Reload failed"
                    font.pixelSize: Theme.f.body
                    font.weight: Font.DemiBold
                }

                CircleButton {
                    icon: "󰅖"
                    onActivated: ReloadWatch.dismiss()
                }
            }

            NText {
                Layout.fillWidth: true
                text: ReloadWatch.message
                wrapMode: Text.Wrap
                color: Theme.c.onDim
                font.family: Theme.f.mono
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.gap

                Item { Layout.fillWidth: true }

                NPillButton {
                    text: "Retry"
                    onActivated: ReloadWatch.retry()
                }
            }
        }
    }
}
