import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Times elsewhere. The family Nothing worked hardest on: thirteen layouts
// in their own app, across four sizes.
//
// Wide shows four cities, small shows one. Which cities is a setting, and
// the list is padded rather than allowed to shrink: a widget whose height
// followed the number of rows would move the desktop under it.
NCard {
    id: root
    property bool simple: false
    property int rows: 4

    readonly property bool empty: WorldTime.clocks.length === 0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        anchors.topMargin: Theme.px(12)
        anchors.bottomMargin: Theme.px(12)
        spacing: 0

        Repeater {
            model: root.rows

            RowLayout {
                required property int index
                readonly property var entry:
                    WorldTime.clocks[index] ?? null

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: entry !== null
                spacing: Theme.px(10)

                NText {
                    Layout.fillWidth: true
                    text: parent.entry?.label ?? ""
                    color: Theme.c.onDim
                    elide: Text.ElideRight
                }

                NText {
                    text: parent.entry?.time ?? "--:--"
                    font.family: Theme.f.mono
                    font.pixelSize: root.simple ? Theme.f.body : Theme.px(18)
                    // Fixed-width figures: four rows of times that shifted
                    // as digits changed would jitter against each other.
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
