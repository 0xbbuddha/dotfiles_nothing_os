import QtQuick
import ".."
import "../.."
import "../../services"

// Large matrix clock.
NCard {
    implicitHeight: Theme.px(72)
    radius: Theme.r.pill

    DisplayText {
        anchors.centerIn: parent
        text: Time.hhmm
        size: Theme.px(50)
    }
}
