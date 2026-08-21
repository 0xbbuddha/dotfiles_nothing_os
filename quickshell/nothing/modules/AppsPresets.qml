import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// The bundled apps. They are ordinary specs, so installing one is a
// copy, and refining it afterwards works exactly like a generated app.
// They double as the examples the model is shown when it writes a new one.
Flickable {
    id: root

    signal seeded(string prompt)

    contentWidth: width
    contentHeight: col.implicitHeight + Theme.pad * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: col
        x: Theme.pad
        y: Theme.px(2)
        width: root.width - Theme.pad * 2
        spacing: Theme.px(6)

        Repeater {
            model: MiniApps.presets

            Rectangle {
                id: row
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Theme.px(58)
                radius: Theme.r.chip
                color: rma.containsMouse ? Theme.c.surface2 : "transparent"
                border.width: rma.containsMouse ? 0 : 1
                border.color: Theme.c.outline
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(12)
                    spacing: Theme.px(12)

                    NIcon {
                        text: row.modelData.icon
                        size: Theme.z.iconM
                        color: Theme.c.on
                        Layout.preferredWidth: Theme.px(20)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(1)

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: Theme.c.on
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.prompt
                            color: Theme.c.onDim
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                            elide: Text.ElideRight
                        }
                    }

                    // Loads the preset's own prompt into the composer, so
                    // the next step is describing how it should differ.
                    NPillButton {
                        text: "PROMPT"
                        onActivated: root.seeded(row.modelData.prompt)
                    }

                    NIcon { text: "󰐕"; size: Theme.z.icon; color: Theme.c.onDim }
                }

                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MiniApps.install(row.modelData.file)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(6)
            text: "Clicking a preset adds a copy to your library. It costs nothing "
                + "and needs no API key, which is also how the model is shown what "
                + "a good app looks like."
            color: Theme.c.onFaint
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
            wrapMode: Text.WordWrap
        }
    }
}
