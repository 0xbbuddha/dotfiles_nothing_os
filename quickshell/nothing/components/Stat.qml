import QtQuick
import QtQuick.Layouts
import ".."

// CPU / RAM / GPU row. Every column has a fixed width so the three rows
// align perfectly, whatever the numbers.
RowLayout {
    id: root
    property string label: ""
    property string icon: ""
    property real value: 0
    // Recent samples for this metric, newest last. Empty falls back to a
    // single bar at the current value, so a caller that has no history
    // still gets something truthful rather than an empty gap.
    property var history: []
    property int temp: -1
    property int hotAt: 80

    Layout.fillWidth: true
    spacing: Theme.px(8)

    NIcon {
        text: root.icon
        size: Theme.z.icon
        color: Theme.c.onDim
        Layout.preferredWidth: Theme.px(13)
    }

    NLabel {
        text: root.label
        Layout.preferredWidth: Theme.px(34)
    }

    HistoryBars {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.px(12)
        values: (root.history ?? []).length > 0 ? root.history : [root.value]
    }

    Text {
        Layout.preferredWidth: Theme.px(30)
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.c.on
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.small
    }

    // Temperature column: always reserved, even when empty, for alignment.
    Item {
        Layout.preferredWidth: Theme.px(34)
        Layout.preferredHeight: Theme.px(12)

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(3)
            visible: root.temp > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(4); height: Theme.px(4); radius: width / 2
                color: root.temp >= root.hotAt ? Theme.c.red : Theme.c.onFaint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.temp + "°"
                color: root.temp >= root.hotAt ? Theme.c.red : Theme.c.onDim
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.small
            }
        }
    }
}
