import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// List of detected audio sinks. A click sets the default sink.
ColumnLayout {
    id: root
    spacing: Theme.px(3)

    Repeater {
        model: Audio.sinks

        Rectangle {
            id: row
            required property var modelData
            readonly property bool current: Audio.isDefault(modelData)

            Layout.fillWidth: true
            implicitHeight: Theme.px(30)
            radius: Theme.r.tiny
            color: row.current ? Theme.c.surface3
                 : (ma.containsMouse ? Theme.c.surface3 : "transparent")

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(8)
                anchors.rightMargin: Theme.px(8)
                spacing: Theme.px(8)

                NIcon {
                    text: Audio.glyphFor(row.modelData)
                    size: Theme.z.iconM
                    color: row.current ? Theme.c.on : Theme.c.onDim
                    Layout.preferredWidth: Theme.px(16)
                }

                Text {
                    Layout.fillWidth: true
                    text: Audio.nameOf(row.modelData)
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.small
                    elide: Text.ElideRight
                }

                Text {
                    visible: row.current
                    text: "ON"
                    color: Theme.c.red
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.micro
                    font.letterSpacing: Theme.f.track
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setSink(row.modelData)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Audio.sinks.length === 0
        text: "No output detected"
        color: Theme.c.onDim
        font.family: Theme.f.sans
        font.pixelSize: Theme.f.small
    }
}
