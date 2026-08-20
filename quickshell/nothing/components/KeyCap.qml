import QtQuick
import ".."

// A key drawn as a keyboard cap.
Rectangle {
    id: root
    property string text: ""

    implicitWidth: Math.max(Theme.px(22), label.implicitWidth + Theme.px(12))
    implicitHeight: Theme.px(21)
    radius: Theme.r.tiny
    color: Theme.c.surface3
    border.width: 1
    border.color: Theme.c.outline

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.c.on
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.tiny
        font.letterSpacing: 0.4
    }
}
