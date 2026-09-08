import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// What the control centre shows, and in what order.
//
// The same shape as BarLayoutEditor, with one difference that changes the
// controls: the bar has three islands, so a row there needs three letters
// to say which one it is in. Here there is one list per kind, so a row
// needs one button, and it is the same button in both directions.
//
// Reading the lists through Config.ccZone rather than binding to the
// adapter properties directly: those are not JavaScript arrays, and a
// Repeater handed one shows nothing at all.
ColumnLayout {
    id: root

    // "tiles" or "footer".
    required property string zone
    property string emptyHint: ""

    readonly property var ids: (Config.ccTiles && Config.ccFooter)
        ? Config.ccZone(root.zone) : []
    readonly property var spare: (Config.ccTiles && Config.ccFooter)
        ? CcRegistry.unplaced(root.zone) : []

    Layout.fillWidth: true
    spacing: Theme.px(4)

    // A Column and not this ColumnLayout, for its move transition:
    // pressing an arrow reorders the list, and without this the two rows
    // swap between one frame and the next, which reads as the list having
    // been redrawn rather than as something having moved.
    Column {
        id: rows
        Layout.fillWidth: true
        spacing: Theme.px(4)

        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.med
                easing.type: Theme.ease
            }
        }

        Repeater {
            model: root.ids

            Rectangle {
                id: row
                required property string modelData
                required property int index

                width: rows.width
                implicitHeight: Theme.px(34)
                height: implicitHeight
                radius: Theme.r.tiny
                color: rowMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(6)
                    spacing: Theme.px(8)

                    NIcon {
                        text: CcRegistry.icon(root.zone, row.modelData)
                        size: Theme.z.icon
                        color: Theme.c.onDim
                    }

                    NText {
                        Layout.fillWidth: true
                        text: CcRegistry.label(root.zone, row.modelData)
                        elide: Text.ElideRight
                    }

                    // Greyed at the ends rather than hidden, so the row
                    // does not change width as it travels up the list.
                    CircleButton {
                        icon: "󰅃"
                        size: Theme.px(20)
                        opacity: row.index > 0 ? 1 : 0.25
                        onActivated: if (row.index > 0)
                            Config.ccMove(root.zone, row.index, -1)
                    }

                    CircleButton {
                        icon: "󰅀"
                        size: Theme.px(20)
                        opacity: row.index < root.ids.length - 1 ? 1 : 0.25
                        onActivated: if (row.index < root.ids.length - 1)
                            Config.ccMove(root.zone, row.index, 1)
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(22)
                        onActivated: Config.ccToggle(root.zone, row.modelData)
                    }
                }
            }
        }
    }

    NText {
        Layout.fillWidth: true
        visible: root.ids.length === 0
        text: root.emptyHint
        color: Theme.c.onFaint
    }

    // ── Everything left out ───────────────────────────────────────────
    // Two lines here where the placed rows have one: a row already in the
    // panel is identified by a name you have just seen on screen, and one
    // that is not needs to say what it would do.
    NLabel {
        Layout.topMargin: Theme.px(8)
        text: "Not shown"
        visible: root.spare.length > 0
    }

    Repeater {
        model: root.spare

        Rectangle {
            id: spareRow
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: Theme.px(38)
            radius: Theme.r.tiny
            color: Theme.c.surface2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(6)
                spacing: Theme.px(8)

                NIcon {
                    text: spareRow.modelData.icon
                    size: Theme.z.icon
                    color: Theme.c.onFaint
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    NText { text: spareRow.modelData.label; elide: Text.ElideRight }
                    NText {
                        Layout.fillWidth: true
                        text: spareRow.modelData.hint
                        color: Theme.c.onDim
                        elide: Text.ElideRight
                    }
                }

                CircleButton {
                    icon: "󰐕"
                    size: Theme.px(22)
                    onActivated: Config.ccToggle(root.zone, spareRow.modelData.id)
                }
            }
        }
    }
}
