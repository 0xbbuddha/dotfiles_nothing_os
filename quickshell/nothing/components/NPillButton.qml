import QtQuick
import ".."

// Discreet pill button, red on hover when destructive.
Rectangle {
    id: root
    property string text: ""
    property bool danger: false
    signal activated()

    implicitWidth: label.implicitWidth + Theme.px(24)
    implicitHeight: Theme.px(28)
    radius: height / 2
    color: ma.containsMouse
        ? (root.danger ? Theme.c.red : Theme.c.on)
        : Theme.c.surface3
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: (ma.containsMouse && !root.danger) ? Theme.c.surface : Theme.c.on
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.small
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
