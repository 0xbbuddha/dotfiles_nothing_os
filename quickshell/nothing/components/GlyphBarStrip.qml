import QtQuick
import ".."
import "../services"

// The Glyph Bar: seven segments, stacked.
//
// Six carry the message and the seventh is the camera light. Underneath
// them the hardware has sixty-three mini-LEDs, nine to a segment, but that
// is the control granularity and not the appearance: they sit behind a
// diffuser with Nothing's bleed-free treatment, so what you see is six
// solid squares of light. Their own reviewers put it as "much finer
// control than the segmentation on the surface would suggest".
//
// An earlier version drew the nine as a visible three by three grid. That
// is the schematic, not the object. A segment that is half lit is a square
// glowing from its lower half with a soft edge where the diffuser gives
// out, which is what the gradient below is for.
//
// All seven are evenly spaced. The camera light was given a wider gap at
// first, on the reasoning that it is not part of the row you read; set on
// its own it just looked stranded, and the strip stopped being one object.
Item {
    id: root

    readonly property int segments: GlyphBar.segments

    property color onColor: "#ffffff"
    property real onOpacity: GlyphEvents.level.on
    property real offOpacity: GlyphEvents.level.off


    property bool demo: false
    property real demoValue: 0
    // A preview can hold demoValue still instead of running the sweep.
    property bool animate: true

    property var fills: root.compute()

    function compute(): var {
        if (root.demo) {
            const out = [];
            const lit = root.demoValue * root.segments;
            for (let i = 0; i < root.segments; i++)
                out.push(Math.max(0, Math.min(1, lit - i)));
            return out;
        }

        const ev = GlyphEvents.event;

        // Dark at rest. Not a dim reading: an earlier version kept every
        // segment on a live value, and CPU and network move on every tick,
        // so the strip animated without stopping and read as a fault.
        if (ev === "")
            return [0, 0, 0, 0, 0, 0];

        // A held snapshot, so the second and a half it is up does not
        // jitter under the reader.
        if (ev === "reveal")
            return GlyphEvents.snapshot;

        const out = [];

        // Exactly these groups, expanded onto the six segments.
        if (GlyphEvents.frameKind === "zones") {
            for (let i = 0; i < root.segments; i++)
                out.push(0);
            for (const g of GlyphEvents.frameZones) {
                const r = GlyphEvents.groupRange(
                    g, GlyphEvents.frameGroups, root.segments);
                for (let i = r.from; i < r.to; i++)
                    out[i] = 1;
            }
            return out;
        }

        // A running point rather than a level: one segment lit, the rest
        // out. Fractional, so it slides between segments.
        if (GlyphEvents.frameKind === "point") {
            const at = GlyphEvents.eventValue * (root.segments - 1);
            for (let i = 0; i < root.segments; i++)
                out.push(Math.max(0, 1 - Math.abs(i - at)));
            return out;
        }

        // Everything else spans the whole bar: six squares read as one
        // gauge, which is the precision the coarse segmentation hides.
        const lit = GlyphEvents.eventValue * root.segments;
        for (let i = 0; i < root.segments; i++)
            out.push(Math.max(0, Math.min(1, lit - i)));
        return out;
    }

    onDemoValueChanged: if (root.demo) root.fills = root.compute();

    SequentialAnimation {
        running: root.demo && root.animate
        loops: Animation.Infinite
        NumberAnimation {
            target: root; property: "demoValue"
            from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 500 }
        NumberAnimation {
            target: root; property: "demoValue"
            to: 0; duration: 900; easing.type: Easing.InCubic
        }
        PauseAnimation { duration: 900 }
    }

    Connections {
        target: GlyphEvents
        enabled: !root.demo
        function onEventChanged(): void { root.fills = root.compute(); }
        function onEventValueChanged(): void { root.fills = root.compute(); }
        function onFrameKindChanged(): void { root.fills = root.compute(); }
        function onFrameZonesChanged(): void { root.fills = root.compute(); }
        function onSnapshotChanged(): void { root.fills = root.compute(); }
    }

    // A segment is square, so its size is whichever dimension runs out
    // first. Seven squares and six equal gaps, per GlyphBar.aspect.
    readonly property real gap: GlyphBar.gap
    readonly property real seg: Math.min(
        root.width, root.height / GlyphBar.aspect)

    // Lit and unlit, as colours rather than opacities, because the fill is
    // a gradient between them and a gradient of one colour at two
    // opacities is the same thing said less directly.
    function lamp(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    Column {
        anchors.centerIn: parent
        width: root.seg
        spacing: root.seg * root.gap

        Repeater {
            model: root.segments

            Rectangle {
                required property int index

                width: root.seg
                height: root.seg
                // The shell's own corner, the one the control centre card
                // uses. Rounder than this and a segment reads as a pill;
                // the real ones are squares with the corner just taken off.
                radius: Theme.px(4)

                // Not readonly: the Behavior below drives it through the
                // binding, and a readonly property refuses that write.
                property real fill:
                    Math.max(0, Math.min(1, root.fills[index] ?? 0))

                // Brightness, not a fill line. Nine LEDs behind Nothing's
                // bleed-free diffuser do not show a level inside a
                // segment; the segment gets brighter. A gradient was tried
                // and was wrong twice over: it drew a hairline of light
                // along an empty segment, and its stops collide at both
                // ends of the range, which Qt does not define.
                color: root.lamp(root.onColor, root.offOpacity
                    + (root.onOpacity - root.offOpacity) * fill)

                Behavior on fill {
                    NumberAnimation { duration: Theme.fast }
                }
            }
        }

        // The camera light. Used for nothing else: the moment it means two
        // things it stops meaning "you are being recorded".
        //
        // It blinks rather than sitting on. A steady lamp reads as a status
        // that happens to be true; a blinking one reads as something
        // happening right now. Slow, and never fully out.
        Rectangle {
            id: cam
            width: root.seg
            height: root.seg
            radius: Theme.px(4)

            property real beat: root.onOpacity

            color: GlyphEvents.recording
                ? root.lamp(Theme.c.red, cam.beat)
                : root.lamp(Theme.c.red, 0.06)

            Behavior on color {
                enabled: !GlyphEvents.recording
                ColorAnimation { duration: Theme.med }
            }

            SequentialAnimation {
                running: GlyphEvents.recording
                loops: Animation.Infinite
                // Reset on stop, or the light freezes wherever in the
                // pulse the recording happened to end.
                onRunningChanged: if (!running) cam.beat = root.onOpacity

                NumberAnimation {
                    target: cam; property: "beat"
                    to: root.onOpacity * 0.22
                    duration: 620; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: cam; property: "beat"
                    to: root.onOpacity
                    duration: 620; easing.type: Easing.InOutSine
                }
            }
        }
    }
}
