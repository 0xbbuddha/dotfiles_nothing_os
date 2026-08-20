import QtQuick
import QtQuick.Layouts
import ".."

// Clickable icon + slider + percentage. Used for volume and brightness.
RowLayout {
    id: root
    property string icon: ""
    property real value: 0
    property color accent: Theme.c.on
    property real split: -1
    signal moved(real v)
    signal iconClicked()

    Layout.fillWidth: true
    spacing: Theme.px(9)

    NIcon {
        text: root.icon
        size: Theme.z.iconM
        color: Theme.c.onDim
        Layout.preferredWidth: Theme.px(16)

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.px(4)
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    NSlider {
        Layout.fillWidth: true
        value: root.value
        accent: root.accent
        split: root.split
        onMoved: (v) => root.moved(v)
    }

    Text {
        Layout.preferredWidth: Theme.px(30)
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.c.onDim
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.small
    }
}
