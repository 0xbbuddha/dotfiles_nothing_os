import QtQuick
import ".."
import "../services"

// The Glyph Strip: three arcs around where the camera would be.
//
// Nothing's Phone (3a) interface, and none of it is guessed. Their own
// developer kit gives the zones and their direction of travel, and the
// angles below were measured off the kit's own diagram rather than
// eyeballed:
//
//   C1..C20   286 to 338 degrees, C1 at the bottom left
//   A1..A11    73 to 122 degrees, A1 at the top
//   B1..B5    221 to 245 degrees, B1 at the bottom right
//
// Degrees run clockwise from twelve o'clock. It is a broken ring, not a
// circle: the gaps at the top, the lower right and the left are as much
// part of the shape as the arcs.
//
// Drawn on one canvas. Thirty-six rotated rectangles would each need their
// own transform and would still not give the rounded ends an arc segment
// has, and an arc is arithmetic rather than a shape you can stack.
Item {
    id: root

    // The zones, in the order a gauge fills them: clockwise from the top,
    // which is A, then B, then C.
    readonly property var arcs: [
        { id: "A", from:  73, to: 122, count: 11 },
        { id: "B", from: 221, to: 245, count:  5 },
        { id: "C", from: 286, to: 338, count: 20 }
    ]
    readonly property int total: 36

    property color onColor: "#ffffff"
    property real onOpacity: GlyphEvents.level.on
    property real offOpacity: GlyphEvents.level.off

    property bool demo: false
    property real demoValue: 0
    property bool animate: true

    // One entry per zone, 0..1, in the arcs' own order.
    property var fills: root.compute()

    function compute(): var {
        const out = [];

        // Dark at rest, as the bar is, and for the same reason.
        if (!root.demo && GlyphEvents.event === "") {
            for (let i = 0; i < root.total; i++)
                out.push(0);
            return out;
        }

        if (root.demo || GlyphEvents.event !== "reveal") {
            const v = root.demo ? root.demoValue : GlyphEvents.eventValue;
            const kind = root.demo ? "level" : GlyphEvents.frameKind;

            // Exactly these groups, expanded onto this ring's zones. A
            // composed rhythm addresses groups so it plays the same shape
            // on three arcs as on six segments.
            if (kind === "zones") {
                for (let i = 0; i < root.total; i++)
                    out.push(0);
                for (const g of GlyphEvents.frameZones) {
                    const r = GlyphEvents.groupRange(
                        g, GlyphEvents.frameGroups, root.total);
                    for (let i = r.from; i < r.to; i++)
                        out[i] = 1;
                }
                return out;
            }

            // A running point rather than a level: one zone lit, the rest
            // out. Fractional, so it moves smoothly between zones instead
            // of jumping.
            if (kind === "point") {
                const at = v * (root.total - 1);
                for (let i = 0; i < root.total; i++)
                    out.push(Math.max(0, 1 - Math.abs(i - at)));
                return out;
            }

            const lit = v * root.total;
            for (let i = 0; i < root.total; i++)
                out.push(Math.max(0, Math.min(1, lit - i)));
            return out;
        }

        // A reveal gives one reading per arc: three, not thirty-six. The
        // ring has three shapes and pretending otherwise would put a
        // boundary where the eye cannot see one.
        if (GlyphEvents.event === "reveal") {
            const snap = GlyphEvents.snapshot;
            for (let a = 0; a < root.arcs.length; a++)
                for (let i = 0; i < root.arcs[a].count; i++) {
                    const v = (snap[a] ?? 0) * root.arcs[a].count - i;
                    out.push(Math.max(0, Math.min(1, v)));
                }
            return out;
        }

        for (let i = 0; i < root.total; i++)
            out.push(0);
        return out;
    }

    onDemoValueChanged: if (root.demo) root.fills = root.compute();

    SequentialAnimation {
        running: root.demo && root.animate
        loops: Animation.Infinite
        NumberAnimation {
            target: root; property: "demoValue"
            from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic
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

    onFillsChanged: ring.requestPaint()
    onOnColorChanged: ring.requestPaint()
    onOnOpacityChanged: ring.requestPaint()
    onOffOpacityChanged: ring.requestPaint()

    Canvas {
        id: ring
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.reset();

            const cx = w / 2, cy = h / 2;
            const side = Math.min(w, h);
            // The band sits just inside the edge, its width a fixed share
            // of the disc so the ring keeps its proportions at any size.
            const band = side * 0.075;
            const r = side / 2 - band / 2 - side * 0.02;

            ctx.lineCap = "round";
            ctx.lineWidth = band;

            let n = 0;
            for (const arc of root.arcs) {
                // A hair of gap between zones, so the segmentation reads
                // without the arc breaking into beads.
                const step = (arc.to - arc.from) / arc.count;
                const inset = step * 0.14;

                for (let i = 0; i < arc.count; i++) {
                    const f = Math.max(0, Math.min(1, root.fills[n] ?? 0));
                    n++;

                    // Canvas angles run counter-clockwise from three
                    // o'clock; the zone table runs clockwise from twelve.
                    const a0 = (arc.from + i * step + inset - 90) * Math.PI / 180;
                    const a1 = (arc.from + (i + 1) * step - inset - 90) * Math.PI / 180;

                    const alpha = root.offOpacity
                        + (root.onOpacity - root.offOpacity) * f;
                    ctx.strokeStyle = Qt.rgba(root.onColor.r, root.onColor.g,
                                              root.onColor.b, alpha);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, a0, a1, false);
                    ctx.stroke();
                }
            }

            // Recording turns the short arc red, and only that one. There
            // is no dedicated lamp on this hardware, so B is borrowed: it
            // is the shortest, so it never reads as the ring itself.
            if (GlyphEvents.recording) {
                const arc = root.arcs[1];
                const step = (arc.to - arc.from) / arc.count;
                const inset = step * 0.14;
                ctx.strokeStyle = Qt.rgba(Theme.c.red.r, Theme.c.red.g,
                                          Theme.c.red.b, root.onOpacity * cam.beat);
                for (let i = 0; i < arc.count; i++) {
                    const a0 = (arc.from + i * step + inset - 90) * Math.PI / 180;
                    const a1 = (arc.from + (i + 1) * step - inset - 90) * Math.PI / 180;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, a0, a1, false);
                    ctx.stroke();
                }
            }
        }
    }

    // Blinks rather than sitting on: a steady lamp reads as a status that
    // happens to be true, a blinking one as something happening now.
    QtObject {
        id: cam
        property real beat: 1
    }

    SequentialAnimation {
        running: GlyphEvents.recording
        loops: Animation.Infinite
        onRunningChanged: if (!running) { cam.beat = 1; ring.requestPaint(); }
        NumberAnimation {
            target: cam; property: "beat"; to: 0.22
            duration: 620; easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: cam; property: "beat"; to: 1
            duration: 620; easing.type: Easing.InOutSine
        }
    }

    Connections {
        target: cam
        function onBeatChanged(): void { ring.requestPaint(); }
    }
}
