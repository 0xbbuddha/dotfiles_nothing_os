import QtQuick
import ".."

// Small hover label.
// visible follows 'shown' directly: binding it to opacity stopped the
// animation from starting and the label stayed invisible.
Rectangle {
    id: root
    property string text: ""
    property bool shown: false

    implicitWidth: label.implicitWidth + Theme.px(14)
    implicitHeight: Theme.px(22)
    radius: Theme.r.tiny
    color: Theme.c.surface2
    border.width: 1
    border.color: Theme.c.outline

    // Visible while shown is true, plus the exit fade.
    // A mere "visible: opacity > 0.01" stops the enter animation from
    // starting when the element begins hidden.
    visible: shown || opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    // Always above neighbouring elements on the card
    z: 100

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.c.on
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.small
        renderType: Text.QtRendering
    }
}
