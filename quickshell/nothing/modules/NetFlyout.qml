import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../components/panels"
import "../services"

// Small Wi-Fi or Bluetooth panel, independent of settings. The content
// itself lives in NetPanel, which the control centre hosts inline.
Item {
    id: root
    readonly property string kind: GlobalState.netPanel
    readonly property bool open: kind !== ""

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

        NetPanel {
            id: panel
            kind: root.kind
            active: root.open
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
        }
    }
}
