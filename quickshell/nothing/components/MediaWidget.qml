import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Desktop "cover" tile. With no cover, show a readable composition
// rather than a large, almost empty black rectangle.
RowLayout {
    id: root
    spacing: Theme.gap

    NCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Image {
            id: art
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        // Scrim so the text stays readable on the cover
        Rectangle {
            anchors.fill: parent
            visible: art.status === Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
            }
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.px(12)
            spacing: Theme.px(1)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: art.status !== Image.Ready

                AppIcon {
                    size: Theme.px(14)
                    appId: Player.desktopEntry
                    visible: Player.desktopEntry !== ""
                }

                NLabel {
                    Layout.fillWidth: true
                    text: Player.identity
                    elide: Text.ElideRight
                }
            }

            NText {
                Layout.fillWidth: true
                text: Player.cleanTitle
                color: art.status === Image.Ready ? Theme.c.onArt : Theme.c.on
                font.pixelSize: Theme.f.body
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            NText {
                Layout.fillWidth: true
                text: Player.subtitle
                visible: text !== "" && text !== Player.cleanTitle
                color: art.status === Image.Ready ? Theme.c.onArtDim : Theme.c.onDim
                elide: Text.ElideRight
            }

            // Thin progress at the bottom of the tile
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.px(6)
                implicitHeight: Theme.px(2)
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.18)
                visible: Player.hasLength

                Rectangle {
                    width: parent.width * Player.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.c.red
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Player.playPause()
        }
    }

    NCard {
        Layout.preferredWidth: Theme.px(56)
        Layout.fillHeight: true

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.px(10)

            NIcon {
                Layout.alignment: Qt.AlignHCenter
                text: Player.playing ? "󰏤" : "󰐊"
                size: Theme.px(17)
                color: playPauseMa.containsMouse ? Theme.c.red : Theme.c.on

                MouseArea {
                    id: playPauseMa
                    anchors.fill: parent
                    anchors.margins: -Theme.px(8)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Player.playPause()
                }
            }

            NIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "󰒭"
                size: Theme.px(15)
                color: !Player.canNext ? Theme.c.onFaint
                     : (nextMa.containsMouse ? Theme.c.red : Theme.c.onDim)

                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    anchors.margins: -Theme.px(8)
                    hoverEnabled: true
                    enabled: Player.canNext
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Player.next()
                }
            }
        }
    }
}
