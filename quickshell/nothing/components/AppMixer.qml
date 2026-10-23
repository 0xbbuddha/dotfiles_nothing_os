import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Per-application volume, reused by the CC and the GameBar.
ColumnLayout {
    id: root
    // Settings > Sound: also show and switch each app's output.
    property bool routes: false
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(6)

                    NText {
                        Layout.fillWidth: true
                        text: Audio.appName(row.modelData)
                        elide: Text.ElideRight
                    }

                    // Where it plays; click for the next output.
                    Rectangle {
                        id: route
                        readonly property var sink: root.routes ? AudioRoutes.sinkOf(row.modelData) : null
                        visible: root.routes && Audio.sinks.length > 1 && route.sink !== null
                        implicitWidth: Math.min(Theme.px(170), routeText.implicitWidth + Theme.px(22))
                        implicitHeight: Theme.px(20)
                        radius: Theme.r.pill
                        color: rma.containsMouse ? Theme.c.surface3 : Theme.c.surface2

                        NText {
                            id: routeText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, route.width - Theme.px(14))
                            elide: Text.ElideRight
                            text: (route.sink ? Audio.glyphFor(route.sink) + " " + Audio.nameOf(route.sink) : "")
                            font.pixelSize: Theme.f.tiny
                            color: Theme.c.onDim
                        }

                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !AudioRoutes.busy
                            onClicked: AudioRoutes.cycle(row.modelData)
                        }
                    }
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
