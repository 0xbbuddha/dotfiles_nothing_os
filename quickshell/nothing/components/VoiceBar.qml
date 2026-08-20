import QtQuick
import QtQuick.Layouts
import QtMultimedia
import ".."

// In-place voice note transport. A hollow circle and a red rail,
// nothing that looks like a system media player.
Item {
    id: root
    property string path: ""

    readonly property bool playing:
        player.playbackState === MediaPlayer.PlayingState
    readonly property real dur: Math.max(0, player.duration)
    readonly property real progress: dur > 0
        ? Math.max(0, Math.min(1, pos / dur)) : 0

    property real pos: 0

    implicitHeight: Theme.px(36)

    onPathChanged: {
        player.stop();
        root.pos = 0;
    }
    onVisibleChanged: if (!visible) player.stop()

    function toggle(): void {
        if (root.path === "")
            return;
        if (root.playing)
            player.pause();
        else
            player.play();
    }

    function seek(v: real): void {
        if (root.dur <= 0)
            return;
        player.position = Math.round(Math.max(0, Math.min(1, v)) * root.dur);
        root.pos = player.position;
    }

    function clock(ms: real): string {
        const t = Math.max(0, Math.floor((ms || 0) / 1000));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }

    MediaPlayer {
        id: player
        source: root.path !== "" ? ("file://" + root.path) : ""
        audioOutput: AudioOutput { volume: 1.0 }
        onPositionChanged: root.pos = position
        onDurationChanged: if (!root.playing) root.pos = 0
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                root.pos = 0;
        }
    }

    Timer {
        running: root.playing
        interval: 80
        repeat: true
        onTriggered: root.pos = player.position
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.px(10)

        CircleButton {
            icon: root.playing ? "󰏤" : "󰐊"
            filled: root.playing
            size: Theme.px(30)
            onActivated: root.toggle()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: rail
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Theme.z.rail
                radius: height / 2
                color: Theme.c.surface3

                Rectangle {
                    width: Math.max(height, rail.width * root.progress)
                    height: parent.height
                    radius: height / 2
                    color: Theme.c.red
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.px(6)
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => root.seek(m.x / Math.max(1, rail.width))
                onPositionChanged: (m) => {
                    if (pressed)
                        root.seek(m.x / Math.max(1, rail.width));
                }
            }
        }

        Text {
            text: root.clock(root.pos)
                + (root.dur > 0 ? "  " + root.clock(root.dur) : "")
            color: Theme.c.onDim
            font.family: Theme.f.mono
            font.pixelSize: Theme.f.micro
        }
    }
}
