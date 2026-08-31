import QtQuick
import ".."
import "../.."

// Sixty marks and two hands: the minutes are readable off the face.
NCard {
    DialFace {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Theme.px(26)
        height: width
        face: "ticks"
    }
}
