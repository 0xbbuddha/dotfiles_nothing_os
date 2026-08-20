import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Rec like ii's overlay: start IS stop. During a rec, one big Stop,
// never the Screen/Region buttons which would restart it.
ColumnLayout {
    id: root
    anchors.fill: parent
    spacing: Theme.px(10)

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(12)

        Rectangle {
            Layout.preferredWidth: Theme.px(40)
            Layout.preferredHeight: Theme.px(40)
            radius: Recorder.recording ? Theme.px(8) : width / 2
            color: recMa.containsMouse
                ? (Recorder.recording ? Theme.c.on : Theme.c.red)
                : (Recorder.recording ? Theme.c.red : Theme.c.surface3)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on radius { NumberAnimation { duration: Theme.fast } }

            Rectangle {
                anchors.centerIn: parent
                width: Recorder.recording ? Theme.px(14) : Theme.px(14)
                height: width
                radius: Recorder.recording ? Theme.px(2) : width / 2
                color: recMa.containsMouse && Recorder.recording
                    ? Theme.c.surface : Theme.c.on
            }

            MouseArea {
                id: recMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Recorder.recording)
                        Recorder.stop();
                    else
                        Recorder.start("screen", false);
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(1)

            Text {
                Layout.fillWidth: true
                text: Recorder.recording ? Recorder.timecode() : "00:00"
                color: Recorder.recording ? Theme.c.red : Theme.c.on
                font.family: Theme.f.display
                font.pixelSize: Theme.px(22)
                renderType: Text.QtRendering
            }

            NLabel {
                text: Recorder.recording ? "Click to stop" : "Standby"
                dim: !Recorder.recording
            }
        }
    }

    Row {
        Layout.fillWidth: true
        spacing: Theme.px(6)
        visible: Recorder.recording

        NPillButton {
            text: "Stop"
            danger: true
            onActivated: Recorder.stop()
        }
        NPillButton {
            text: "Folder"
            onActivated: Recorder.openFolder()
        }
    }

    Row {
        Layout.fillWidth: true
        spacing: Theme.px(6)
        visible: !Recorder.recording

        NPillButton {
            text: "Screen"
            onActivated: Recorder.start("screen", false)
        }
        NPillButton {
            text: "Region"
            onActivated: Recorder.start("region", false)
        }
        NPillButton {
            text: "Audio"
            onActivated: Recorder.start("screen", true)
        }
        NPillButton {
            text: "Folder"
            onActivated: Recorder.openFolder()
        }
    }

    Item { Layout.fillHeight: true }
}
