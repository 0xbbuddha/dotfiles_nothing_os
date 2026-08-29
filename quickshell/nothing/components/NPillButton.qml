import QtQuick
import ".."

// Discreet pill button, red on hover when destructive.
Rectangle {
    id: root
    property string text: ""
    property bool danger: false
    // 0 = size to the label, as everywhere else in the shell. Set it and
    // the pill stops growing and the label elides instead: generated
    // apps can carry a label of any length.
    property real maxWidth: 0
    signal activated()

    implicitWidth: root.maxWidth > 0
        ? Math.min(root.maxWidth, label.implicitWidth + Theme.px(24))
        : label.implicitWidth + Theme.px(24)
    implicitHeight: Theme.px(28)
    radius: height / 2
    color: ma.containsMouse
        ? (root.danger ? Theme.c.red : Theme.c.on)
        : Theme.c.surface3
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    NText {
        id: label
        anchors.centerIn: parent
        width: root.maxWidth > 0
            ? Math.min(implicitWidth, root.width - Theme.px(20)) : implicitWidth
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.text
        color: (ma.containsMouse && !root.danger) ? Theme.c.surface : Theme.c.on
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
