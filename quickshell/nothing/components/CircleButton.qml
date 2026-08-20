import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property bool filled: false
    property real size: Theme.px(21)
    signal activated()

    width: size; height: size; radius: size / 2
    color: filled ? Theme.c.on : (ma.containsMouse ? Theme.c.surface3 : "transparent")
    border.width: filled ? 0 : 1
    border.color: Theme.c.outline

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    NIcon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size * 0.46
        color: root.filled ? Theme.c.surface : Theme.c.on
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }
}
