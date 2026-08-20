import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Volume, sinks and mixer: opened by right-clicking the Sound pill.
Item {
    id: root
    readonly property bool open: GlobalState.audioPanel

    implicitWidth: Theme.px(320)
    implicitHeight: card.implicitHeight
    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? 0 : -Theme.px(8)

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    NCard {
        id: card
        width: root.implicitWidth
        implicitHeight: col.implicitHeight + Theme.pad * 2

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
            spacing: Theme.px(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NIcon {
                    text: Audio.muted ? "󰝟" : "󰕾"
                    size: Theme.z.iconM
                }

                Text {
                    Layout.fillWidth: true
                    text: "Sound"
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.big
                    font.weight: Font.Medium
                }
            }

            LevelRow {
                Layout.fillWidth: true
                icon: Audio.muted ? "󰝟" : "󰕾"
                value: Audio.volume
                accent: Audio.muted ? Theme.c.onFaint : Theme.c.on
                onIconClicked: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
                onMoved: (v) => { if (Audio.audio) Audio.audio.volume = v; }
            }

            NLabel { text: "Output" }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Theme.px(140), sinks.implicitHeight)
                contentHeight: sinks.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                SinkList {
                    id: sinks
                    width: parent.width
                }
            }

            NLabel { text: "Apps" }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Theme.px(180), mixer.implicitHeight)
                contentHeight: mixer.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: mixer.implicitHeight > 0

                AppMixer {
                    id: mixer
                    width: parent.width
                }
            }
        }
    }
}
