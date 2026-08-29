import QtQuick
import QtQuick.Layouts
import ".."

// Row of exclusive choices, the active one in solid white.
RowLayout {
    id: root
    property var options: []      // [{ label, value }]
    property var current: null
    signal picked(var value)

    Layout.fillWidth: true
    spacing: Theme.px(4)

    Repeater {
        model: root.options

        Rectangle {
            id: seg
            required property var modelData
            readonly property bool active:
                typeof modelData.value === "number"
                    ? Math.abs((root.current ?? 0) - modelData.value) < 0.001
                    : root.current === modelData.value

            Layout.fillWidth: true
            implicitHeight: Theme.px(32)
            radius: Theme.r.chip
            color: active ? Theme.c.on
                 : (sma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            NText {
                anchors.centerIn: parent
                text: seg.modelData.label
                color: seg.active ? Theme.c.surface : Theme.c.onDim
                font.weight: seg.active ? Font.Medium : Font.Normal
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
