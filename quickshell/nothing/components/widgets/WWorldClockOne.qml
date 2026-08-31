import QtQuick
import ".."
import "../.."
import "../../services"

// One city, square. The first in the list: choosing which is the point of
// the setting, so there is nothing to pick here.
NCard {
    id: root
    readonly property bool empty: WorldTime.clocks.length === 0
    readonly property var entry: WorldTime.clocks[0] ?? null

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(2)

        NText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.entry?.time ?? "--:--"
            font.family: Theme.f.mono
            font.pixelSize: Theme.px(30)
            font.features: ({ "tnum": 1 })
        }

        NLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.entry?.label ?? ""
        }
    }
}
