import QtQuick
import ".."
import "../.."
import "../../services"

// The Ndot face. One clock, one look: the dial and the plain numerals are
// separate widgets, so adding one never changes the size of another.
NCard {
    radius: Theme.r.pill

    DisplayText {
        anchors.centerIn: parent
        text: Time.hhmm
        size: Theme.px(50)
    }
}
