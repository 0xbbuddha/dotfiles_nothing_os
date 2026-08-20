import QtQuick
import ".."

// Dot slider, with the value readable on the right.
//
// The emitted value stays continuous: only the display is quantised.
// Rounding to the nearest dot would make some defaults unreachable
// (scale 1.0 on a 0.6–1.4 range falls between two dots).
Item {
    id: root

    property real value: 0.5              // 0..1, like NSlider
    property int count: 18
    property real dot: Theme.px(4)
    property color accent: Theme.c.red
    property string display: ""           // formatted value, empty = hidden
    signal moved(real v)

    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    implicitHeight: Math.max(Theme.px(18), label.implicitHeight)

    Item {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: label.visible ? label.left : parent.right
        anchors.rightMargin: label.visible ? Theme.px(12) : 0
        height: root.dot * 2

        readonly property int lastLit: Math.round(root.clamped * (root.count - 1))

        Repeater {
            model: root.count

            Rectangle {
                required property int index
                readonly property bool lit: index <= track.lastLit
                readonly property bool head: index === track.lastLit

                width: root.dot
                height: root.dot
                radius: root.dot / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.count > 1
                    ? index * (track.width - root.dot) / (root.count - 1) : 0
                color: lit ? root.accent : Theme.c.onFaint
                scale: head ? 1.7 : 1

                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Behavior on scale {
                    NumberAnimation { duration: Theme.fast; easing.type: Theme.ease }
                }
            }
        }
    }

    Text {
        id: label
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.display !== ""
        text: root.display
        color: Theme.c.onDim
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.small
    }

    MouseArea {
        anchors.fill: track
        anchors.margins: -Theme.px(6)
        cursorShape: Qt.PointingHandCursor

        function pick(mx: real): void {
            root.moved(Math.max(0, Math.min(1, (mx + Theme.px(6)) / track.width)));
        }

        onPressed: (m) => pick(m.x)
        onPositionChanged: (m) => { if (pressed) pick(m.x); }
    }
}
