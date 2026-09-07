import QtQuick
import QtQuick.Layouts
import ".."

// L C R, for one element of the bar.
//
// The lit letter is where the element is now, and pressing it takes the
// element out of the bar: that is one gesture for "move" and "remove"
// rather than a separate delete button on every row, which on nineteen
// rows is nineteen buttons that do nothing most of the time.
RowLayout {
    id: root
    required property string itemId
    // Which island this row is being shown under, "" for none.
    required property string here

    spacing: Theme.px(3)

    Repeater {
        model: [
            { zone: "left",   letter: "L" },
            { zone: "centre", letter: "C" },
            { zone: "right",  letter: "R" }
        ]

        Rectangle {
            id: chip
            required property var modelData
            readonly property bool on: root.here === modelData.zone

            implicitWidth: Theme.px(22)
            implicitHeight: Theme.px(22)
            radius: Theme.r.tiny
            color: chip.on ? Theme.c.on
                 : (chipMa.containsMouse ? Theme.c.surface3 : "transparent")
            border.width: chip.on ? 0 : 1
            border.color: Theme.c.outline
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            NText {
                anchors.centerIn: parent
                text: chip.modelData.letter
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.tiny
                color: chip.on ? Theme.c.surface : Theme.c.onDim
            }

            MouseArea {
                id: chipMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.barPlace(root.itemId,
                                           chip.on ? "" : chip.modelData.zone)
            }
        }
    }
}
