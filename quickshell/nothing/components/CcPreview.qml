import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// A miniature of the control centre, drawn from the lists it configures.
//
// Glyphs rather than live tiles, for the same reason the bar preview uses
// them: a real control centre in a settings page means a second clock, a
// second Bluetooth scan and a second battery poll, all to show an
// arrangement. The arrangement is what is being edited.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + Theme.px(20)
    radius: Theme.r.chip
    color: Theme.veil(0.04)

    // The panel floats over a wallpaper, so the preview floats over a
    // field of dots: against nothing it would read as a list.
    DotField {
        anchors.fill: parent
        step: Theme.px(9)
        dotRadius: Theme.px(0.8)
        baseAlpha: 0.5
    }

    readonly property var tiles: Config.ccTiles ? Config.ccZone("tiles") : []
    readonly property var foot: Config.ccFooter ? Config.ccZone("footer") : []
    readonly property int cols: Math.max(2, Math.min(4, Config.ccColumns))

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.px(20), Theme.px(250))
        implicitHeight: body.implicitHeight + Theme.px(14)
        height: implicitHeight
        radius: Theme.r.panel
        color: Theme.c.surface

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.px(7)
            spacing: Theme.px(5)

            // The header line, so the miniature is recognisable as the
            // panel and not as a grid of chips.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(4)
                Repeater {
                    model: 4
                    Rectangle {
                        implicitWidth: Theme.px(7)
                        implicitHeight: Theme.px(9)
                        radius: Theme.px(1)
                        color: Theme.c.onFaint
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: Theme.px(26)
                    implicitHeight: Theme.px(4)
                    radius: Theme.px(2)
                    color: Theme.c.outline
                }
            }

            Flow {
                id: grid
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.px(4)
                readonly property real cell:
                    (width - spacing * (root.cols - 1)) / root.cols

                Repeater {
                    model: root.tiles

                    Rectangle {
                        required property string modelData
                        width: grid.cell
                        height: Theme.px(16)
                        radius: Theme.r.tiny
                        color: Theme.c.surface2

                        NIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.px(4)
                            anchors.verticalCenter: parent.verticalCenter
                            text: CcRegistry.icon("tiles", parent.modelData)
                            size: Theme.px(8)
                            color: Theme.c.onDim
                        }
                    }
                }
            }

            NLabel {
                Layout.fillWidth: true
                visible: root.tiles.length === 0
                text: "No tiles"
                color: Theme.c.onFaint
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(2)
                spacing: Theme.px(4)

                Rectangle {
                    Layout.fillWidth: true
                    visible: Config.ccCaffeine
                    implicitHeight: Theme.px(12)
                    radius: Theme.r.tiny
                    color: Theme.c.surface2
                }

                Item {
                    Layout.fillWidth: true
                    visible: !Config.ccCaffeine
                }

                Repeater {
                    model: root.foot

                    Rectangle {
                        required property string modelData
                        implicitWidth: Theme.px(14)
                        implicitHeight: Theme.px(12)
                        radius: Theme.px(3)
                        color: Theme.c.surface2

                        NIcon {
                            anchors.centerIn: parent
                            text: CcRegistry.icon("footer", parent.modelData)
                            size: Theme.px(7)
                            color: Theme.c.onDim
                        }
                    }
                }
            }
        }
    }
}
