import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Playback tile. One source: large cover. Several: one row each, so you
// can pause YouTube without touching Spotify.
Item {
    id: root
    readonly property int n: (Player.players ?? []).length
    implicitHeight: n === 0 ? 0 : (n === 1 ? Theme.px(124) : n * Theme.px(60) + Theme.px(8))
    clip: true
    opacity: n > 0 ? 1 : 0

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.med } }

    MediaWidget {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.px(124)
        visible: root.n === 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.px(6)
        visible: root.n > 1

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
