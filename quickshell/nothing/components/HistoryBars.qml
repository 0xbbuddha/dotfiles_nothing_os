import QtQuick
import ".."

// Recent load as thin vertical bars, oldest on the left.
//
// This replaces a row of dots that showed only the present value. A dot
// gauge answers "how loaded is it right now", which the figure beside it
// already answers; the bars answer "and was it just now", which nothing
// else here did. Thin repeated marks stay in the Nothing language either
// way, so the change costs no identity.
//
// Drawn on a Canvas rather than as a Repeater of Rectangles: forty items
// rebuilt every two seconds, in five rows, is a lot of scene graph for
// forty little sticks.
Item {
    id: root

    property var values: []
    property color barColor: Theme.c.on
    property color idleColor: Theme.c.onFaint
    // Above this, the bar turns red. The row is meant to be glanced at,
    // so trouble has to read without the figure being consulted.
    property real hotAt: 0.85
    property color hotColor: Theme.c.red

    // A floor so a near-idle metric still draws a baseline rather than
    // disappearing, which reads as "no data" instead of "nothing to do".
    property real minBar: Theme.px(1)

    implicitHeight: Theme.px(12)

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const vals = root.values ?? [];
            const n = Math.max(1, vals.length);
            const w = width;
            const h = height;
            if (w <= 0 || h <= 0)
                return;

            const slot = w / n;
            const bar = Math.max(1, Math.floor(slot * 0.55));

            for (let i = 0; i < vals.length; i++) {
                const v = Math.max(0, Math.min(1, vals[i]));
                const bh = Math.max(root.minBar, v * h);
                const x = Math.round(i * slot + (slot - bar) / 2);
                ctx.fillStyle = v >= root.hotAt ? root.hotColor
                              : (v <= 0.02 ? root.idleColor : root.barColor);
                ctx.fillRect(x, Math.round(h - bh), bar, Math.round(bh));
            }
        }
    }

    onValuesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onBarColorChanged: canvas.requestPaint()
    onIdleColorChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
