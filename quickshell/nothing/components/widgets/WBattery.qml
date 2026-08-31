import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// The battery, at length.
//
// A row of cells rather than a bar. Nothing draws their battery widget as
// discrete segments and it is the better reading anyway: a continuous bar
// invites you to judge a length, where twelve cells you can count tell you
// where you are at a glance.
//
// Hidden outright on a machine with no battery. A desktop reports a
// fictional one at a permanent 100 %, and a widget that always says the
// same thing is worse than no widget.
NCard {
    id: root
    property bool simple: false

    readonly property bool empty: !Batt.present
    readonly property int cells: 12
    readonly property color ink: Batt.charging ? Theme.c.red
        : (Batt.low ? Theme.c.red : Theme.c.on)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        anchors.topMargin: Theme.px(14)
        anchors.bottomMargin: Theme.px(14)
        spacing: Theme.px(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)

            NIcon {
                text: Batt.charging ? "󰂄" : "󰁹"
                size: Theme.z.iconM
                color: root.ink
            }
            NLabel { Layout.fillWidth: true; text: "Battery" }
            NLabel {
                visible: Batt.knowsTime
                text: Batt.pretty(Batt.secondsLeft)
                     + (Batt.charging ? " to full" : " left")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            DisplayText {
                text: Batt.percent
                size: Theme.px(34)
                color: root.ink
            }
            NText {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: Theme.px(6)
                text: "%"
                color: Theme.c.onDim
            }
            Item { Layout.fillWidth: true }
        }

        Row {
            Layout.fillWidth: true
            spacing: Theme.px(3)

            Repeater {
                model: root.cells

                Rectangle {
                    required property int index

                    // The last cell takes the rounding error, so the row
                    // always ends exactly at the card's edge.
                    readonly property real w:
                        (root.width - Theme.px(32) - Theme.px(3) * (root.cells - 1))
                        / root.cells

                    width: w
                    height: Theme.px(14)
                    radius: Theme.px(2)
                    color: index < Math.round(Batt.fraction * root.cells)
                        ? root.ink : Theme.c.onFaint
                    Behavior on color { ColorAnimation { duration: Theme.med } }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.simple
            spacing: Theme.px(10)

            NLabel {
                Layout.fillWidth: true
                text: Batt.watts > 0.1
                    ? Batt.watts.toFixed(1) + " W" : ""
            }
            NLabel {
                visible: Batt.knowsHealth
                text: "Health " + Batt.health + "%"
            }
        }
    }
}
