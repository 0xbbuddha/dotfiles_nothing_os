import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Quick Look: the date and the sky, on one card.
//
// Nothing's own name for it, and the widget they lead with. Two things
// people check in the same glance, so putting them in one card saves a
// slot and, more to the point, saves the second glance.
//
// The date is the loud half. Weather changes through the day and the date
// does not, so the date is what you learn the shape of and the weather is
// what you read.
NCard {
    id: root
    property bool simple: false

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(18)
        anchors.rightMargin: Theme.px(18)
        anchors.topMargin: Theme.px(14)
        anchors.bottomMargin: Theme.px(14)
        spacing: Theme.px(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(12)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                NLabel { text: Time.dayShort }

                DisplayText {
                    text: Time.dayNum
                    size: Theme.px(44)
                }
            }

            // The sky at the size the dot icon deserves. On the wide card
            // there is room for it to be the counterweight to the day
            // number rather than a footnote beside it.
            DotGlyph {
                Layout.alignment: Qt.AlignVCenter
                kind: Weather.dotKind
                width: Theme.px(50)
                height: Theme.px(50)
                color: Theme.c.on
            }
        }

        // One rule between the halves, in the shell's own hairline.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.c.outline
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(10)

            // The date keeps its natural width and the sky gives way.
            // The other way round, a long forecast ("pluie eparse a
            // proximite") ate the date down to "Monday 31 ..." while
            // sitting there in full itself.
            NText {
                text: Time.dateLong
                color: Theme.c.onDim
            }

            // "12 SUNNY", their phrasing: the reading and the sky on one
            // line, tracked and capitalised, never a sentence.
            NText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                visible: Weather.ready
                text: Weather.temp + "° " + Weather.desc
                color: Theme.c.on
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.f.track
                font.pixelSize: Theme.f.micro
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.simple && Weather.ready
            spacing: Theme.px(12)

            NLabel { Layout.fillWidth: true; text: Weather.city }
            NLabel { text: "H " + Weather.hi + "°" }
            NLabel { text: "L " + Weather.lo + "°"; color: Theme.c.onFaint }
        }
    }
}
