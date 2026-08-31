import QtQuick
import ".."
import "../.."
import "../../services"

// The artwork tile for whatever is playing.
//
// One source, one fixed size. An earlier version grew a row per player,
// which meant the widget below it moved whenever a second tab started a
// video. Several sources at once are the business of the control centre
// and of "Playing, sources".
Item {
    id: root
    readonly property bool empty: !Player.active

    MediaWidget {
        anchors.fill: parent
        visible: !root.empty
    }
}
