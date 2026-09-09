import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// What goes in the bar, and where.
//
// One block per island, plus everything currently in none of them. Each
// row carries its own three letters: pressing one moves the element to
// that island, pressing the lit one takes it out of the bar entirely.
// Order inside an island is the arrows.
//
// Reading the lists through Config.barZone rather than binding to the
// adapter properties directly: those are not JavaScript arrays, and a
// Repeater handed one shows nothing at all.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: Theme.px(6)

    Repeater {
        model: BarRegistry.zones

        ColumnLayout {
            id: zoneBlock
            required property string modelData
            readonly property var ids: Config.barLeft && Config.barCentre
                && Config.barRight ? Config.barZone(modelData) : []

            Layout.fillWidth: true
            Layout.topMargin: Theme.px(6)
            spacing: Theme.px(4)

            RowLayout {
                Layout.fillWidth: true
                NLabel { text: BarRegistry.zoneLabel(zoneBlock.modelData) }
                Item { Layout.fillWidth: true }
                NLabel {
                    text: zoneBlock.ids.length === 0
                        ? "empty" : zoneBlock.ids.length + ""
                    color: Theme.c.onFaint
                }
            }

            // Dragged rather than nudged with a pair of arrows: moving
            // something three places was four presses and no idea where it
            // would land. DragList positions the rows itself, so the gap
            // opens where the row is going while you are still holding it.
            DragList {
                id: rows
                Layout.fillWidth: true
                count: zoneBlock.ids.length
                rowHeight: Theme.px(34)
                rowSpacing: Theme.px(4)
                onReordered: (from, to) =>
                    Config.barMove(zoneBlock.modelData, from, to - from)

                Repeater {
                    model: zoneBlock.ids

                    // `index` is not declared here and not assigned here:
                    // DragRow already requires it, so the Repeater fills it
                    // in. Writing `index: index` at this call site would
                    // have bound the property to itself, which is how a
                    // bar element once woke up with its window undefined.
                    DragRow {
                        id: row
                        required property string modelData

                        list: rows

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r.tiny
                            color: (row.dragging || rowMa.containsMouse)
                                ? Theme.c.surface3 : Theme.c.surface2
                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(10)
                                anchors.rightMargin: Theme.px(6)
                                spacing: Theme.px(8)

                                DragHandle { row: row }

                                NIcon {
                                    text: BarRegistry.icon(row.modelData)
                                    size: Theme.z.icon
                                    color: Theme.c.onDim
                                }

                                NText {
                                    Layout.fillWidth: true
                                    text: BarRegistry.label(row.modelData)
                                    elide: Text.ElideRight
                                }

                                ZonePicker {
                                    itemId: row.modelData
                                    here: zoneBlock.modelData
                                }
                            }
                        }
                    }
                }
            }

            NText {
                Layout.fillWidth: true
                visible: zoneBlock.ids.length === 0
                text: "Nothing here. An empty island is not drawn at all."
                color: Theme.c.onFaint
            }
        }
    }

    // ── Everything left out ───────────────────────────────────────────
    NLabel {
        Layout.topMargin: Theme.px(10)
        text: "Not in the bar"
        visible: BarRegistry.unplaced().length > 0
    }

    Repeater {
        model: (Config.barLeft && Config.barCentre && Config.barRight)
            ? BarRegistry.unplaced() : []

        Rectangle {
            id: spare
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: Theme.px(34)
            radius: Theme.r.tiny
            color: Theme.c.surface2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(6)
                spacing: Theme.px(8)

                NIcon {
                    text: spare.modelData.icon
                    size: Theme.z.icon
                    color: Theme.c.onFaint
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    NText { text: spare.modelData.label; elide: Text.ElideRight }
                    NText {
                        Layout.fillWidth: true
                        text: spare.modelData.hint
                        color: Theme.c.onDim
                        elide: Text.ElideRight
                    }
                }

                ZonePicker { itemId: spare.modelData.id; here: "" }
            }
        }
    }
}
