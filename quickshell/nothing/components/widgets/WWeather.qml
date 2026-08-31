import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Weather: large card on the left, summary and extremes on the right.
Item {
    id: root
    // Reduced version: no high and low.
    property bool simple: false

    implicitHeight: Theme.z.cardS
    opacity: Weather.ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.med } }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        NCard {
            Layout.preferredWidth: Theme.px(126)
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.px(3)

                NText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.temp + "°"
                    font.pixelSize: Theme.px(24)
                }

                NIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.glyph
                    size: Theme.px(20)
                }

                NText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.px(2)
                    Layout.maximumWidth: Theme.px(110)
                    text: Weather.city
                    color: Theme.c.onDim
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gap

            NCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 42
                radius: Theme.r.pill

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(8)
                    anchors.rightMargin: Theme.px(12)
                    spacing: Theme.px(8)

                    Rectangle {
                        Layout.preferredWidth: Theme.px(26)
                        Layout.preferredHeight: Theme.px(26)
                        radius: width / 2
                        color: Theme.c.surface2
                        NIcon { anchors.centerIn: parent; text: Weather.glyph; size: Theme.px(13) }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: Weather.desc
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 54
                spacing: Theme.gap

                NCard {
                    Layout.preferredWidth: height
                    Layout.fillHeight: true
                    radius: width / 2

                    NText {
                        anchors.centerIn: parent
                        text: Weather.temp + "°"
                        font.pixelSize: Theme.f.big
                    }
                }

                NCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.simple
                    radius: Theme.r.card

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.px(2)

                        RowLayout {
                            spacing: Theme.px(5)
                            NIcon { text: "󰁝"; size: Theme.px(9); color: Theme.c.onDim }
                            Text {
                                text: Weather.hi + "°"
                                font.family: Theme.f.mono
                                font.pixelSize: Theme.f.small
                                color: Theme.c.on
                            }
                        }

                        RowLayout {
                            spacing: Theme.px(5)
                            NIcon { text: "󰁅"; size: Theme.px(9); color: Theme.c.onDim }
                            Text {
                                text: Weather.lo + "°"
                                font.family: Theme.f.mono
                                font.pixelSize: Theme.f.small
                                color: Theme.c.onDim
                            }
                        }
                    }
                }
            }
        }
    }
}
