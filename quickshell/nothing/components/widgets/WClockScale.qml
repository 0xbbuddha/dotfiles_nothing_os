import QtQuick
import ".."
import "../.."

// The same dial, drawn with hairlines. Nothing calls this one "scale" and
// the thick-handed one "bold"; nothing else separates them.
NCard {
    DialFace {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Theme.px(26)
        height: width
        face: "ticks"
        hands: "scale"
    }
}
