import QtQuick
import ".."
import "../.."
import "../../services"

// The dots alone, no card. Nothing's own digital clock ships in a solid
// and a transparent style; this is the transparent one, for a desktop
// where the wallpaper is meant to be the background and not a backdrop.
Item {
    DisplayText {
        anchors.centerIn: parent
        text: Time.hhmm
        size: Theme.px(54)
    }
}
