import QtQuick
import QtQuick.Layouts
import ".."

// Preview frame on a dot field: what is placed inside reads as shown on a
// screen, not drawn on a flat fill.
//
// Used for the crosshair and wallpaper, where judging the look matters more
// than reading a value.
Rectangle {
    id: root

    property string caption: ""
    property real step: Theme.px(11)
    default property alias content: holder.data

    Layout.fillWidth: true
    implicitHeight: Theme.px(150)
    radius: Theme.r.chip
    color: Theme.c.surface2
    clip: true

    readonly property int cols: Math.max(1, Math.floor(width / root.step))
    readonly property int rows: Math.max(1, Math.floor(height / root.step))

    Grid {
        anchors.centerIn: parent
        columns: root.cols
        rowSpacing: root.step - Theme.px(1)
        columnSpacing: root.step - Theme.px(1)

        // Safety cap: the field stays decorative; it must never cost more
        // than the content it dresses.
        Repeater {
            model: Math.min(root.cols * root.rows, 900)

            Rectangle {
                width: Theme.px(1)
                height: Theme.px(1)
                radius: width / 2
                color: Theme.c.onFaint
            }
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    NLabel {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.px(10)
        visible: root.caption !== ""
        text: root.caption
    }
}
