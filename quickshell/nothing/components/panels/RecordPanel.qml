import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"

// Screen recording options, inline under the control centre tile: what to
// capture and which audio goes with it. The Recorder service holds the
// choices; this is only the face of them.
ColumnLayout {
    id: root
    spacing: Theme.px(10)

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(8)

        NIcon {
            text: Recorder.recording ? "󰙧" : "󰑊"
            size: Theme.z.iconM
        }

        NText {
            Layout.fillWidth: true
            text: "Recording"
            font.pixelSize: Theme.f.big
            font.weight: Font.Medium
        }

        NText {
            visible: Recorder.recording
            text: Recorder.timecode()
            font.family: Theme.f.mono
            color: Theme.c.red
        }
    }

    NLabel { text: "Area" }

    SegmentedControl {
        Layout.fillWidth: true
        enabled: !Recorder.recording
        opacity: Recorder.recording ? 0.4 : 1
        options: [
            { label: "Screen", value: "screen" },
            { label: "Region", value: "region" }
        ]
        current: Recorder.mode
        onPicked: (v) => Recorder.mode = v
    }

    NLabel { text: "Audio" }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(10)

        NIcon { text: "󰓃"; size: Theme.z.icon; color: Theme.c.onDim }
        NText { Layout.fillWidth: true; text: "System sound" }
        NSwitch {
            checked: Recorder.wantSound
            onToggled: (v) => Recorder.wantSound = v
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(10)
        opacity: Audio.hasMic ? 1 : 0.4

        NIcon {
            text: Recorder.wantMic ? "󰍬" : "󰍭"
            size: Theme.z.icon
            color: Theme.c.onDim
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            NText { text: "Microphone" }
            NText {
                visible: !Audio.hasMic
                text: "no input device"
                color: Theme.c.onDim
                font.pixelSize: Theme.f.micro
            }
        }
        NSwitch {
            checked: Recorder.wantMic
            enabled: Audio.hasMic
            onToggled: (v) => { if (Audio.hasMic) Recorder.wantMic = v; }
        }
    }

    NPillButton {
        Layout.alignment: Qt.AlignLeft
        Layout.topMargin: Theme.px(2)
        text: Recorder.recording
            ? "Stop"
            : (Recorder.picking ? "Cancel" : "Start")
        danger: Recorder.recording
        onActivated: {
            GlobalState.controlCenterOpen = false;
            Recorder.toggle();
        }
    }
}
