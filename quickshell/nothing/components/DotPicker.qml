import QtQuick
import QtQuick.Layouts
import ".."

// Exclusive choice: each option carries its witness dot.
//
// Same API as SegmentedControl, which it replaces in settings.
// Switching from a solid pad to a witness dot lets long labels breathe,
// which segments truncated as soon as there were more than three options.
Flow {
    id: root

    property var options: []          // [{ label, value }]
    property var current: null
    signal picked(var value)

    Layout.fillWidth: true
    spacing: Theme.px(6)

    Repeater {
        model: root.options

        Rectangle {
            id: opt
            required property var modelData

            readonly property bool active:
                typeof modelData.value === "number"
                    ? Math.abs((root.current ?? 0) - modelData.value) < 0.001
                    : root.current === modelData.value

            implicitWidth: inner.implicitWidth + Theme.px(20)
            implicitHeight: Theme.px(28)
            radius: Theme.r.chip
            color: opt.active ? Theme.c.surface3
                 : (oma.containsMouse ? Theme.c.surface3 : "transparent")
            border.width: 1
            border.color: opt.active ? Theme.c.red : Theme.c.outline

            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }

            Row {
                id: inner
                anchors.centerIn: parent
                spacing: Theme.px(7)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(4)
                    height: width
                    radius: width / 2
                    color: opt.active ? Theme.c.red : Theme.c.onFaint
                    scale: opt.active ? 1.4 : 1

                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.fast; easing.type: Theme.ease }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: opt.modelData.label
                    color: opt.active ? Theme.c.on : Theme.c.onDim
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.small
                }
            }

            MouseArea {
                id: oma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(opt.modelData.value)
            }
        }
    }
}
