import QtQuick
import ".."

// Game-bar rail button: icon, tracked label, active state.
Item {
    id: root
    property string icon: ""
    property string label: ""
    property string tip: ""
    property bool active: false
    property bool danger: false
    property bool marked: false
    signal activated()
    signal altActivated()

    implicitWidth: Math.max(Theme.px(44), lab.implicitWidth + Theme.px(16))
    implicitHeight: Theme.px(52)

    Rectangle {
        anchors.fill: parent
        radius: Theme.r.chip
        color: root.active
            ? (root.danger ? Theme.c.red : Theme.c.surface3)
            : (ma.containsMouse ? Theme.c.surface2 : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(3)

        NIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            size: Theme.z.iconL
            color: root.active && root.danger ? Theme.c.on : (root.active ? Theme.c.on : Theme.c.onDim)
        }

        NLabel {
            id: lab
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            dim: !root.active
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.px(6)
        width: Theme.px(5); height: width; radius: width / 2
        color: Theme.c.red
        visible: root.marked
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            if (m.button === Qt.RightButton) root.altActivated();
            else root.activated();
        }
    }

    Tooltip {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.px(8)
        text: root.tip
        shown: ma.containsMouse && root.tip !== ""
    }
}
