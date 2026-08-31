import QtQuick
import ".."
import "../.."
import "../../services"

// Hours over minutes, in the Ndot face. Nothing's lock screen sets the
// time this way, and stacking buys the digits twice the height for the
// same width, which is the whole point of the dot font.
NCard {
    Column {
        anchors.centerIn: parent
        spacing: -Theme.px(6)

        DisplayText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.hhmm.slice(0, 2)
            size: Theme.px(56)
        }
        DisplayText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.hhmm.slice(3, 5)
            size: Theme.px(56)
            color: Theme.c.onDim
        }
    }
}
