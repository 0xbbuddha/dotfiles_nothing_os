import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

ColumnLayout {
    id: root
    anchors.fill: parent
    spacing: Theme.px(8)

    readonly property var caps: [0, 60, 120, 144, 165, 240]

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: Config.gameFpsLimit > 0 ? String(Config.gameFpsLimit) : "OFF"
        color: Theme.c.on
        font.family: Theme.f.display
        font.pixelSize: Theme.px(26)
        renderType: Text.QtRendering
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.px(4)

        Repeater {
            model: root.caps

            Rectangle {
                required property var modelData
                width: Theme.px(30)
                height: Theme.px(18)
                radius: height / 2
                color: Config.gameFpsLimit === modelData ? Theme.c.red : Theme.c.surface3
                opacity: Game.mangohudAvailable ? 1 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData === 0 ? "OFF" : String(parent.modelData)
                    color: Theme.c.on
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.micro
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Game.mangohudAvailable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Game.setFpsLimit(parent.modelData)
                }
            }
        }
    }

    NLabel {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: Game.mangohudAvailable ? "MangoHud" : "mangohud missing"
    }
}
