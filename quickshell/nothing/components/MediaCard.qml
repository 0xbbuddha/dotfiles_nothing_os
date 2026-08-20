import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// One or more MPRIS sources, each with its own pause.
NCard {
    id: root
    color: Theme.c.surface2
    radius: Theme.r.chip
    implicitHeight: col.implicitHeight + Theme.px(18)
    clip: true

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(9)
        spacing: Theme.px(8)

        Text {
            visible: (Player.players ?? []).length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(56)
            verticalAlignment: Text.AlignVCenter
            text: "Nothing is playing"
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.body
        }

        Repeater {
            model: Player.players ?? []

            PlayerRow {
                required property var modelData
                player: modelData
                Layout.fillWidth: true
            }
        }
    }
}
