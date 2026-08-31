import QtQuick
import ".."
import "../.."

// Twelve dots and a red minute hand. Says the hour at a glance and no
// more, which is the closest a dial gets to the dot matrix.
NCard {
    DialFace {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Theme.px(26)
        height: width
        face: "dots"
    }
}
