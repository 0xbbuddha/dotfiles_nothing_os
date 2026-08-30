import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../components/panels"
import "../services"

// Light sliders, opened by clicking the Light pill.
// Screen: two phases (software gamma, then panel). Keyboard separate.
Item {
    id: root
    readonly property bool open: GlobalState.lightPanel

    implicitWidth: Theme.px(320)
    implicitHeight: card.implicitHeight
    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? 0 : -Theme.px(8)

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    NCard {
        id: card
        width: root.implicitWidth
        implicitHeight: panel.implicitHeight + Theme.pad * 2

        BrightnessPanel {
            id: panel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
        }
    }
}
