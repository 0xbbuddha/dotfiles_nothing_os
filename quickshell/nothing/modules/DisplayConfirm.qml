import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// "Keep this?", after a change that could have blacked a screen out.
//
// It exists on every screen, not just the focused one, because the whole
// point is that one of them may have just gone dark: whichever still
// draws is the one that carries the way back. It takes no keyboard focus
// (the panel already holds it, and two exclusive layers on one screen
// fight), so the keys are handled there and this offers the mouse.
//
// The safety is the timer, not the window. Even with nothing visible
// anywhere, the previous layout returns on its own.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    visible: Displays.confirming

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-displays-confirm"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Only the card takes clicks: the desktop underneath stays usable
    // while you decide.
    mask: Region { item: card }

    NCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - Theme.px(96)
        width: Theme.px(400)
        implicitHeight: body.implicitHeight + Theme.pad * 2
        height: implicitHeight
        outlined: true
        clip: true

        scale: Displays.confirming ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.px(10)

            NLabel { text: "D I S P L A Y S" }

            NText {
                Layout.fillWidth: true
                text: "Keep this screen setup?"
                font.pixelSize: Theme.f.body
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            NText {
                Layout.fillWidth: true
                text: "Going back in " + Displays.countdown
                    + (Displays.countdown === 1 ? " second" : " seconds")
                color: Theme.c.onDim
            }

            // The countdown as a rule that runs out, so it reads without
            // being read.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.z.rail
                radius: height / 2
                color: Theme.c.surface3

                Rectangle {
                    width: parent.width * Math.max(0, Displays.countdown)
                        / Math.max(1, Displays.grace)
                    height: parent.height
                    radius: height / 2
                    color: Theme.c.red
                    Behavior on width { NumberAnimation { duration: 900 } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.px(8)

                Item { Layout.fillWidth: true }

                NPillButton {
                    text: "Undo"
                    onActivated: Displays.revert()
                }

                NPillButton {
                    text: "Keep"
                    onActivated: Displays.keep()
                }
            }
        }
    }
}
