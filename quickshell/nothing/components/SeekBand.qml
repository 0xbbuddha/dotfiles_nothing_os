import QtQuick
import ".."
import "../services"

// Playback position as a fine ruler: elapsed on the left, what is left to
// play on the right, and the ticks between them.
//
// Repeated thin marks are the Nothing language, the same one the Glyph
// Matrix and the dot gauges speak. A ruler also says something a plain
// filled bar does not: how far along you are is readable at a glance
// because the marks give it a scale.
//
// The right-hand figure counts down rather than showing the total. What
// you want to know mid-track is how long is left, not how long it was.
Item {
    id: root

    // Defaults to whatever is playing. A per-source row passes its own.
    property var player: null
    readonly property var p: root.player ?? Player.current

    readonly property real len: Player.lengthOf(root.p)
    readonly property real pos: root.dragging
        ? root.dragFraction * root.len
        : Player.positionOf(root.p)
    readonly property real fraction: root.len > 0
        ? Math.max(0, Math.min(1, root.pos / root.len)) : 0
    readonly property bool seekable: (root.p?.canSeek ?? false) && root.len > 0

    // Over album art the ground is an image, not a theme surface, so the
    // ink has to be handed in rather than followed from the palette.
    property color inkOn: Theme.c.on
    property color inkOff: Theme.c.onFaint
    property color inkText: Theme.c.onDim

    // Tick pitch. Fine enough to read as a ruler, coarse enough that the
    // marks stay separate at every width the shell uses.
    property real pitch: Theme.px(3)
    property real tickHeight: Theme.px(7)

    property bool dragging: false
    property real dragFraction: 0

    implicitHeight: Math.max(root.tickHeight, Theme.px(12))

    NText {
        id: elapsed
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Time.duration(root.pos)
        color: root.inkText
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.tiny
        // Times sit either side of a moving ruler; without fixed-width
        // figures the band would jitter every time a digit changed.
        font.features: ({ "tnum": 1 })
    }

    NText {
        id: remaining
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.len > 0 ? "-" + Time.duration(root.len - root.pos) : "--:--"
        color: root.inkText
        font.family: Theme.f.mono
        font.pixelSize: Theme.f.tiny
        font.features: ({ "tnum": 1 })
    }

    Item {
        id: band
        anchors.left: elapsed.right
        anchors.right: remaining.left
        anchors.leftMargin: Theme.px(8)
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        height: root.tickHeight

        readonly property int count: Math.max(1, Math.floor(width / root.pitch))
        readonly property real lit: band.count * root.fraction

        Repeater {
            model: band.count

            Rectangle {
                required property int index
                width: Math.max(1, Theme.px(1))
                height: band.height
                radius: width / 2
                x: index * (band.width / band.count)
                    + (band.width / band.count - width) / 2
                color: index < band.lit ? root.inkOn : root.inkOff
                // No colour animation: sixty marks crossfading at once on
                // every position tick is a lot of work for something the
                // eye reads as a single edge moving.
            }
        }

        // The playhead is the one red thing here, and the only part that
        // has to be found instantly.
        Rectangle {
            width: Math.max(Theme.px(2), 2)
            height: band.height + Theme.px(4)
            radius: width / 2
            color: Theme.c.red
            visible: root.len > 0
            anchors.verticalCenter: parent.verticalCenter
            x: Math.min(band.width - width,
                        Math.max(0, band.width * root.fraction - width / 2))
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -Theme.px(6)
            anchors.bottomMargin: -Theme.px(6)
            enabled: root.seekable
            cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true

            function fractionAt(mx: real): real {
                return Math.max(0, Math.min(1, mx / Math.max(1, band.width)));
            }

            // Held drags scrub live, so the figures follow the finger and
            // the seek is sent once, on release. Sending on every move
            // floods MPRIS and the player stutters.
            onPressed: (m) => {
                root.dragFraction = fractionAt(m.x);
                root.dragging = true;
            }
            onPositionChanged: (m) => {
                if (root.dragging)
                    root.dragFraction = fractionAt(m.x);
            }
            onReleased: (m) => {
                if (!root.dragging)
                    return;
                root.dragging = false;
                Player.seek(fractionAt(m.x), root.p);
            }
            onCanceled: root.dragging = false
        }
    }
}
