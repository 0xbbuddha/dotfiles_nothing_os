import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// MPRIS sources on title hover: independent pause per player.
NCard {
    id: root
    property bool shown: false
    readonly property bool hovered: hh.hovered

    implicitWidth: Theme.px(280)
    width: implicitWidth
    implicitHeight: col.implicitHeight + Theme.px(20)
    radius: Theme.r.chip
    visible: shown || opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(10)
        spacing: Theme.px(8)

        NLabel { text: "Now playing"; dim: false }

        Repeater {
            model: Player.players ?? []

            PlayerRow {
                required property var modelData
                player: modelData
                Layout.fillWidth: true
            }
        }
    }

    HoverHandler { id: hh }
}
