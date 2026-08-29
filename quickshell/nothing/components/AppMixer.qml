import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Per-application volume, reused by the CC and the GameBar.
ColumnLayout {
    id: root
    spacing: Theme.px(7)

    Repeater {
        model: Audio.streams

        RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.px(8)

            NIcon {
                text: (row.modelData.audio?.muted ?? false) ? "󰝟" : "󰕾"
                size: Theme.z.icon
                color: (row.modelData.audio?.muted ?? false) ? Theme.c.red : Theme.c.onDim
                Layout.preferredWidth: Theme.px(14)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(4)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.modelData.audio)
                        row.modelData.audio.muted = !row.modelData.audio.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(2)

                NText {
                    Layout.fillWidth: true
                    text: Audio.appName(row.modelData)
                    elide: Text.ElideRight
                }

                NSlider {
                    Layout.fillWidth: true
                    value: row.modelData.audio?.volume ?? 0
                    accent: (row.modelData.audio?.muted ?? false)
                        ? Theme.c.onFaint : Theme.c.on
                    onMoved: (v) => { if (row.modelData.audio) row.modelData.audio.volume = v; }
                }
            }

            Text {
                Layout.preferredWidth: Theme.px(28)
                horizontalAlignment: Text.AlignRight
                text: Math.round((row.modelData.audio?.volume ?? 0) * 100)
                color: Theme.c.onDim
                font.family: Theme.f.mono
                font.pixelSize: Theme.f.tiny
            }
        }
    }

    NText {
        Layout.fillWidth: true
        visible: Audio.streams.length === 0
        text: "Nothing is playing."
        color: Theme.c.onDim
    }
}
