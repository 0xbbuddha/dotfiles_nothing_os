import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Two cities, square. Nothing's 1x2, the size between one city and four.
//
// Two is the size most people actually need: where you are and where the
// people you talk to are. Four rows in a square would leave nothing but
// type, so the square gets two and the wide card keeps the rest.
NCard {
    id: root
    property bool simple: false

    readonly property bool empty: WorldTime.clocks.length === 0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(14)
        anchors.topMargin: Theme.px(14)
        anchors.bottomMargin: Theme.px(14)
        spacing: Theme.px(10)

        Repeater {
            model: 2

            ColumnLayout {
                required property int index
                readonly property var entry: WorldTime.clocks[index] ?? null

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: entry !== null
                spacing: 0

                NText {
                    text: parent.entry?.time ?? "--:--"
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.px(24)
                    // Fixed-width figures, so the second row does not
                    // shuffle sideways as the minutes turn.
                    font.features: ({ "tnum": 1 })
                }

                NLabel {
                    Layout.fillWidth: true
                    visible: !root.simple
                    text: parent.entry?.label ?? ""
                    elide: Text.ElideRight
                }
            }
        }
    }
}
