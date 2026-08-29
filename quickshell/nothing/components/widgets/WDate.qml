import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Large day number, full date and week number.
// Height is owned by an Item: a RowLayout would derive its own from its
// children, which are all fillHeight, and the widget would collapse to zero.
Item {
    id: root
    implicitHeight: Theme.z.cardS

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        NCard {
            Layout.preferredWidth: Theme.px(126)
            Layout.fillHeight: true

            DisplayText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Theme.px(3)
                text: Time.dayNum
                size: Theme.px(58)
            }

            NText {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.px(11)
                text: Time.dayShort
                font.weight: Font.DemiBold
                color: Theme.c.red
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.px(10)
                width: Theme.px(13); height: Theme.px(10)
                radius: Theme.px(3)
                color: Theme.c.surface2
            }
        }

        NCard {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Theme.px(20)
                spacing: Theme.px(3)

                NText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Time.dateLong
                    font.pixelSize: Theme.f.body
                    elide: Text.ElideRight
                }

                NLabel {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.px(4)
                    text: "Week " + Time.weekNumber
                }
            }
        }
    }
}
