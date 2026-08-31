import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// What is moving through the wire.
//
// Two traces, down over up, on a shared scale so the one is readable
// against the other. A separate scale per trace would make a trickle of
// uploads look like a torrent whenever nothing was coming down.
NCard {
    id: root
    property bool simple: false

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        anchors.topMargin: Theme.px(14)
        anchors.bottomMargin: Theme.px(14)
        spacing: Theme.px(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)

            NIcon { text: Net.glyph; size: Theme.z.iconM; color: Theme.c.on }
            NLabel { Layout.fillWidth: true; text: "Network" }
            NLabel {
                text: Net.name
                elide: Text.ElideRight
                Layout.maximumWidth: Theme.px(120)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(16)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    spacing: Theme.px(5)
                    NIcon { text: "󰁅"; size: Theme.z.icon; color: Theme.c.red }
                    NText {
                        text: Netflow.human(Netflow.rx)
                        font.family: Theme.f.mono
                        font.features: ({ "tnum": 1 })
                    }
                }
                RowLayout {
                    spacing: Theme.px(5)
                    NIcon { text: "󰁝"; size: Theme.z.icon; color: Theme.c.onDim }
                    NText {
                        text: Netflow.human(Netflow.tx)
                        font.family: Theme.f.mono
                        font.features: ({ "tnum": 1 })
                        color: Theme.c.onDim
                    }
                }
            }
        }

        // Bars, not a line. A polyline needs a Canvas and a repaint on
        // every tick; sixty rectangles bind their own height and the
        // shell already draws its histories this way.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.simple

            Row {
                id: trace
                anchors.fill: parent
                spacing: 1

                readonly property real bw:
                    (width - Netflow.span + 1) / Netflow.span

                Repeater {
                    model: Netflow.span

                    Item {
                        required property int index
                        width: trace.bw
                        height: trace.height

                        readonly property real down:
                            Netflow.rxHistory[index] ?? 0
                        readonly property real up:
                            Netflow.txHistory[index] ?? 0

                        // Half the height each, growing from the middle
                        // line outward, so the two directions read as
                        // directions. An idle link keeps a one-pixel
                        // baseline, and that baseline is neutral: in red
                        // it read as sixty tiny downloads rather than as
                        // the axis it is.
                        Rectangle {
                            width: parent.width
                            readonly property real h: parent.height / 2
                                * Math.min(1, parent.down / Netflow.peak)
                            height: Math.max(1, h)
                            y: parent.height / 2 - height
                            color: h >= 1 ? Theme.c.red : Theme.c.onFaint
                        }

                        Rectangle {
                            width: parent.width
                            height: Math.max(1, parent.height / 2
                                * Math.min(1, parent.up / Netflow.peak))
                            y: parent.height / 2
                            color: Theme.c.onFaint
                        }
                    }
                }
            }
        }
    }
}
