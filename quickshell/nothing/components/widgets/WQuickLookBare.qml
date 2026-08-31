import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Quick Look with the card taken away.
//
// Nothing ships a transparent flavour of this widget beside the carded
// one, and it is a genuinely different thing rather than a colour choice:
// with no card there is no container to sit inside, so it becomes one line
// laid straight on the wallpaper.
//
// Everything is a shade brighter than it would be on a card. A wallpaper
// is whatever the user chose, and onDim over a photograph is unreadable.
Item {
    id: root
    property bool simple: false

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(4)
        anchors.rightMargin: Theme.px(4)
        spacing: Theme.px(14)

        DisplayText {
            text: Time.dayNum
            size: Theme.px(40)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
                Layout.fillWidth: true
                text: Time.dayShort + "  " + Time.monthLong
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.f.track
                font.pixelSize: Theme.f.micro
                elide: Text.ElideRight
            }
            NText {
                Layout.fillWidth: true
                visible: Weather.ready
                text: Weather.temp + "° " + Weather.desc
                color: Theme.c.onDim
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.f.track
                font.pixelSize: Theme.f.micro
                elide: Text.ElideRight
            }
        }

        DotGlyph {
            Layout.alignment: Qt.AlignVCenter
            visible: Weather.ready
            kind: Weather.dotKind
            width: Theme.px(34)
            height: Theme.px(34)
        }
    }
}
