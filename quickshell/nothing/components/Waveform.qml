import QtQuick
import ".."

// Decorative waveform: the played part is lit.
Item {
    id: root
    property real progress: 0
    property bool playing: false
    property int bars: 38
    property real barW: Theme.px(2.5)

    signal seek(real p)

    implicitHeight: Theme.px(16)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Math.max(1, (parent.width - root.bars * root.barW) / (root.bars - 1))

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                readonly property bool played: index < root.progress * root.bars
                // pseudo-random but stable height (no flicker)
                readonly property real amp: {
                    const v = Math.sin(index * 12.9898) * 43758.5453;
                    return 0.28 + Math.abs(v - Math.floor(v)) * 0.72;
                }

                anchors.verticalCenter: parent.verticalCenter
                width: root.barW
                radius: root.barW / 2
                height: Math.max(Theme.px(2), root.implicitHeight * (played ? amp : amp * 0.6))
                color: played ? Theme.c.on : Qt.rgba(1, 1, 1, 0.22)

                Behavior on color { ColorAnimation { duration: Theme.med } }
                Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (m) => root.seek(m.x / root.width)
    }
}
