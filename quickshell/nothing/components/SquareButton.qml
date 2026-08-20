import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property bool danger: false
    property bool lit: false
    signal activated()

    implicitWidth: Theme.px(36)
    implicitHeight: Theme.px(30)
    radius: Theme.r.chip
    color: {
        if (lit) return Theme.c.on;
        if (ma.containsMouse) return danger ? Theme.c.red : Theme.c.surface3;
        return Theme.c.surface2;
    }

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    NIcon {
        anchors.centerIn: parent
        text: root.icon
        size: Theme.z.iconM
        color: root.lit ? Theme.c.surface : Theme.c.on
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
