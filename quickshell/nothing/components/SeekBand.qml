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

    // The caller switches these the instant the art finishes loading, and
    // on -> onArt is a real (if small) step now that on is no longer pure
    // white: without this, the ruler and its label snap instead of fading.
    Behavior on inkOn { ColorAnimation { duration: Theme.fast } }
    Behavior on inkOff { ColorAnimation { duration: Theme.fast } }
    Behavior on inkText { ColorAnimation { duration: Theme.fast } }

    // Tick pitch. Fine enough to read as a ruler, coarse enough that the
    // marks stay separate at every width the shell uses.
    property real pitch: Theme.px(3)
    property real tickHeight: Theme.px(7)

    property bool dragging: false
    property real dragFraction: 0

    // Cava is a shared daemon - see services/Cava.qml - so this only
    // asks for it while there is something playing to move with.
    readonly property bool wantsCava: Player.playing
    onWantsCavaChanged: {
        root.wantsCava ? Cava.addListener() : Cava.removeListener();
        if (!root.wantsCava)
            root.level = 0;
    }
    Component.onCompleted: if (root.wantsCava) Cava.addListener()
    Component.onDestruction: if (root.wantsCava) Cava.removeListener()

    // One smoothed loudness, not Cava's 25 bars drawn raw: a bar per
    // frequency bin read as scattered noise at this size (tried it,
    // looked wrong - a ruler is one line, not a spectrum). Averaged and
    // eased, it reads as the ruler itself breathing with the track
    // rather than a graph bolted onto it.
    property real level: 0
    Connections {
        target: Cava
        function onValuesChanged(): void {
            if (!root.wantsCava)
                return;
            // Peak, not average: 25 bins averaged together flatten every
            // transient into almost nothing, which is why the first cut
            // barely showed at all. The loudest bin of the moment is one
            // number too, just one that actually tracks a beat.
            const vals = Cava.values;
            let peak = 0;
            for (let i = 0; i < vals.length; i++)
                peak = Math.max(peak, vals[i]);
            root.level = root.level * 0.5 + Math.min(1, peak * 1.4) * 0.5;
        }
    }

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
                // Only what is already played breathes - the future
                // stays flat, so there is still one still baseline to
                // read the moving one against.
                readonly property bool lit: index < band.lit
                width: Math.max(1, Theme.px(1))
                height: band.height * (lit ? 1 + root.level * 1.1 : 1)
                y: (band.height - height) / 2
                radius: width / 2
                x: index * (band.width / band.count)
                    + (band.width / band.count - width) / 2
                color: lit
                    ? Qt.rgba(
                        root.inkOn.r + (Theme.c.red.r - root.inkOn.r) * root.level,
                        root.inkOn.g + (Theme.c.red.g - root.inkOn.g) * root.level,
                        root.inkOn.b + (Theme.c.red.b - root.inkOn.b) * root.level,
                        1)
                    : root.inkOff
                // No colour animation beyond the level itself, which is
                // already eased: sixty marks re-blending from a second
                // animator each on every position tick is a lot of work
                // for something the eye reads as a single edge moving.
            }
        }

        // The playhead is the one red thing here, and the only part that
        // has to be found instantly - the beat just makes it swell a
        // little rather than adding a second moving thing beside it.
        Rectangle {
            width: Math.max(Theme.px(2), 2) + root.level * Theme.px(3)
            height: band.height + Theme.px(4) + root.level * Theme.px(7)
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
