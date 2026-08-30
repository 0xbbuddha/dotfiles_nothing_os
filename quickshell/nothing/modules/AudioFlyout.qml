import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../components/panels"
import "../services"

// Volume, sinks and mixer: opened by right-clicking the Sound pill.
Item {
    id: root
    readonly property bool open: GlobalState.audioPanel

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

        AudioPanel {
            id: panel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
        }
    }
}
