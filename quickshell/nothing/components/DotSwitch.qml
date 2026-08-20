import QtQuick
import ".."

// Dot switch: a trail that fills left to right, with a larger head
// dot to mark the position.
//
// Replaces NSwitch in settings. NSwitch stays used by the control centre,
// where the solid pill suits large tiles better.
Item {
    id: root

    property bool checked: false
    property int count: 4
    property real dot: Theme.px(4)
    property real gap: Theme.px(4)
    signal toggled(bool value)

    implicitWidth: root.count * root.dot + (root.count - 1) * root.gap + Theme.px(6)
    implicitHeight: Theme.px(16)

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.count

            Rectangle {
                required property int index

                // Head dot: left at rest, right once active.
                readonly property bool head:
                    root.checked ? index === root.count - 1 : index === 0

                width: root.dot
                height: root.dot
                radius: root.dot / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.checked ? Theme.c.red : Theme.c.onFaint
                scale: head ? 1.7 : 1

                // Duration grows with the index: the trail lights in cascade
                // instead of flipping as one block.
                Behavior on color {
                    ColorAnimation { duration: Theme.fast + index * 45 }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.fast; easing.type: Theme.ease }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Theme.px(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
