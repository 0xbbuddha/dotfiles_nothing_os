import QtQuick
import ".."
import "../.."
import "../../services"

// The battery, in a square.
//
// A ring of dots rather than an arc: the same grammar as everything else
// here, and at this size an arc a few pixels thick reads as a smudge. The
// count is deliberately twenty, so one dot is five per cent and the ring
// can be read without doing arithmetic.
NCard {
    id: root
    property bool simple: false

    readonly property bool empty: !Batt.present
    readonly property int dots: 20
    readonly property color ink: Batt.charging || Batt.low
        ? Theme.c.red : Theme.c.on

    Item {
        id: ring
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Theme.px(34)
        height: width

        readonly property real lit: Batt.fraction * root.dots

        Repeater {
            model: root.dots

            Rectangle {
                required property int index

                readonly property real d: Theme.px(5)
                // From twelve o'clock, clockwise, because that is the
                // direction a gauge fills everywhere else.
                readonly property real a:
                    -Math.PI / 2 + index * 2 * Math.PI / root.dots

                width: d
                height: d
                radius: d / 2
                x: ring.width / 2 + Math.cos(a) * (ring.width - d) / 2 - d / 2
                y: ring.height / 2 + Math.sin(a) * (ring.height - d) / 2 - d / 2
                color: index < ring.lit ? root.ink : Theme.c.onFaint
                Behavior on color { ColorAnimation { duration: Theme.med } }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            DisplayText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Batt.percent
                size: Theme.px(28)
                color: root.ink
            }

            NIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Batt.charging
                text: "󰂄"
                size: Theme.z.icon
                color: Theme.c.red
            }

            NLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !Batt.charging && !root.simple && Batt.knowsTime
                text: Batt.pretty(Batt.secondsLeft)
            }
        }
    }
}
