import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"

// Volume, output sinks and the per-app mixer. Hosted by the flyout
// and, inline, by the control centre.
ColumnLayout {
    id: root
    spacing: Theme.px(8)

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(8)

        NIcon {
            text: Audio.muted ? "󰝟" : "󰕾"
            size: Theme.z.iconM
        }

        NText {
            Layout.fillWidth: true
            text: "Sound"
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
