import QtQuick
import ".."
import "../.."
import "../../services"

// Inter at its lightest. Nothing is not only the dot font: the interface
// itself is set in this grotesque, and at this size it reads as the quiet
// counterpart to the matrix.
NCard {
    radius: Theme.r.pill

    NText {
        anchors.centerIn: parent
        text: Time.hhmm
        font.family: Theme.f.sans
        font.pixelSize: Theme.px(46)
        font.weight: Font.Thin
        font.letterSpacing: Theme.px(2)
        font.features: ({ "tnum": 1 })
    }
}
