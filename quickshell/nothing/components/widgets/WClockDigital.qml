import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Mono numerals with the seconds the dot matrix has no room for.
//
// A RowLayout, not a Row: the seconds sit on the same baseline as the
// hours, and only a layout can align on a baseline. Anchoring a child of a
// positioner is the kind of thing that half works and then stops.
NCard {
    id: root
    // Reduced version: the hour alone, no seconds.
    property bool simple: false

    radius: Theme.r.pill

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.px(8)

        NText {
            Layout.alignment: Qt.AlignBaseline
            text: Time.hhmm
            font.family: Theme.f.mono
            font.pixelSize: Theme.px(42)
            font.weight: Font.Light
            // Fixed-width figures, or the line shifts once a second.
            font.features: ({ "tnum": 1 })
        }

        NText {
            Layout.alignment: Qt.AlignBaseline
            visible: !root.simple
            text: Time.seconds
            color: Theme.c.red
            font.family: Theme.f.mono
            font.pixelSize: Theme.px(19)
            font.features: ({ "tnum": 1 })
        }
    }
}
