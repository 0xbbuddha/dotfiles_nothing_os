import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// One line: the day number, the date, the weekday. For a desktop where
// the date is worth a glance and not a card.
NCard {
    radius: Theme.r.chip

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        spacing: Theme.px(12)

        DisplayText {
            text: Time.dayNum
            size: Theme.px(26)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
                Layout.fillWidth: true
                text: Time.dateLong
                elide: Text.ElideRight
            }
            NLabel { text: Time.dayShort }
        }
    }
}
