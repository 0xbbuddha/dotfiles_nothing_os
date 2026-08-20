import QtQuick
import ".."

// Dot gauge. Stays within the allocated width (OSD, CPU gauges, etc.):
// previously the natural Row overflowed the frame as soon as the value rose.
Item {
    id: root
    property real value: 0        // 0..1 (beyond that, every dot is on)
    property int count: 20
    property real dot: Theme.z.dot
    property color onColor: Theme.c.on
    property color offColor: Theme.c.onFaint
    property real split: -1

    implicitHeight: dot
    implicitWidth: count * dot + Math.max(0, count - 1) * (dot * 0.9)

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            readonly property real slot: root.width / Math.max(1, root.count)
            readonly property real filled: Math.max(0, Math.min(1, root.value))
            readonly property bool lit: index < Math.round(filled * root.count)

            x: index * slot + Math.max(0, (slot - root.dot) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            color: lit ? root.onColor : root.offColor
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
    }

    Rectangle {
        visible: root.split >= 0 && root.split <= 1 && root.width > 0
        width: Theme.px(1)
        height: root.dot + Theme.px(3)
        color: Theme.c.onDim
        anchors.verticalCenter: parent.verticalCenter
        x: root.width * root.split - width / 2
    }
}
