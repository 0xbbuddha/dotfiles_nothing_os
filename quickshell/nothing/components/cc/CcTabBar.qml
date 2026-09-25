import QtQuick
import QtQuick.Layouts
import "../.."
import ".."

// Row of tabs for the control centre's added pages. A generic
// SegmentedControl - a solid white pill for whichever is active - reads
// fine for a two or three-way setting, but stretched across five tabs
// with real content behind them it looked like a row of buttons rather
// than a place belonging to this house. This borrows Settings' own
// sidebar instead: a dot-matrix mark and a red rule marking the current
// one, the rule just turned on its side for a row instead of a column.
RowLayout {
    id: root
    property var options: []   // [{ label, value, glyph }]
    property var current: null
    signal picked(var value)

    Layout.fillWidth: true
    spacing: Theme.px(2)

    Repeater {
        model: root.options

        Item {
            id: seg
            required property var modelData
            readonly property bool active: root.current === seg.modelData.value

            Layout.fillWidth: true
            implicitHeight: Theme.px(46)

            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: Theme.px(3)
                radius: Theme.r.chip
                color: seg.active ? Theme.c.surface2
                     : (sma.containsMouse ? Theme.c.surface2 : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.px(2)
                spacing: Theme.px(4)

                DotMatrix {
                    Layout.alignment: Qt.AlignHCenter
                    pattern: seg.modelData.glyph
                    dot: Theme.px(2.2)
                    gap: Theme.px(1.6)
                    onColor: seg.active ? Theme.c.red : Theme.c.on
                    offColor: Theme.c.onFaint
                    offOpacity: 0.22
                    Behavior on onColor { ColorAnimation { duration: Theme.fast } }
                }

                NText {
                    Layout.alignment: Qt.AlignHCenter
                    text: seg.modelData.label
                    font.pixelSize: Theme.f.micro
                    color: seg.active ? Theme.c.on : Theme.c.onDim
                }
            }

            // The same red rule Settings' rail marks its current page
            // with, run along the bottom edge here instead of the left.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: seg.active ? Theme.px(22) : 0
                height: Theme.px(2)
                radius: 1
                color: Theme.c.red
                Behavior on width {
                    NumberAnimation { duration: Theme.fast; easing.type: Theme.ease }
                }
            }

            MouseArea {
                id: sma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.value)
            }
        }
    }
}
