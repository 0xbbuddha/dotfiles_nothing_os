import QtQuick
import ".."
import "../.."
import "../../services"

// The cover, square, with the controls over it.
//
// A square is the shape a record sleeve already is, so the artwork fills
// it edge to edge and everything else sits on top. The wide tile puts the
// title beside the art; here there is no beside, so the title goes under
// a gradient at the foot and the transport rides the middle.
Item {
    id: root
    readonly property bool empty: !Player.active

    NCard {
        anchors.fill: parent
        visible: !root.empty
        clip: true

        Image {
            id: art
            anchors.fill: parent
            source: Player.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        // No cover: the accent bleeds up from the bottom rather than
        // leaving a black square, the same fallback the row uses.
        Rectangle {
            anchors.fill: parent
            visible: art.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.c.surface2 }
                GradientStop {
                    position: 1.0
                    color: ColorUtils.applyAlpha(Theme.c.red, 0.30)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: art.status === Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.shade(0.88) }
            }
        }

        NIcon {
            anchors.centerIn: parent
            text: Player.playing ? "󰏤" : "󰐊"
            size: Theme.px(26)
            color: art.status === Image.Ready ? Theme.c.onArt : Theme.c.on
            opacity: ma.containsMouse ? 1 : 0.75
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.px(10)
            spacing: 0

            NText {
                width: parent.width
                text: Player.cleanTitle
                color: art.status === Image.Ready ? Theme.c.onArt : Theme.c.on
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            NText {
                width: parent.width
                text: Player.subtitle
                visible: text !== "" && text !== Player.cleanTitle
                color: art.status === Image.Ready ? Theme.c.onArtDim : Theme.c.onDim
                font.pixelSize: Theme.f.tiny
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) Player.next();
                else Player.playPause();
            }
        }
    }
}
