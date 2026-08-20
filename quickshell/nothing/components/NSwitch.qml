import QtQuick
import ".."

// Switch: Nothing red when on.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: Theme.px(30)
    implicitHeight: Theme.px(16)
    radius: height / 2
    color: checked ? Theme.c.red : Theme.c.surface3

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: parent.height - Theme.px(5)
        height: width
        radius: width / 2
        color: Theme.c.on
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - Theme.px(2.5) : Theme.px(2.5)
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.ease } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.px(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
