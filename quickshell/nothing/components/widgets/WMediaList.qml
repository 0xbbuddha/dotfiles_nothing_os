import QtQuick
import ".."
import "../.."
import "../../services"

// One row per source, each with its own position band.
//
// Fixed height, holding two rows. A third source scrolls rather than
// stretching the widget: a tile that grew whenever a tab started playing
// pushed everything below it down the desktop, which is exactly the
// restlessness this catalogue is meant to be free of.
Item {
    id: root
    readonly property bool empty: (Player.players ?? []).length === 0

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: Theme.px(6)

            Repeater {
                model: Player.players ?? []

                PlayerRow {
                    required property var modelData
                    player: modelData
                    width: col.width
                }
            }
        }
    }
}
