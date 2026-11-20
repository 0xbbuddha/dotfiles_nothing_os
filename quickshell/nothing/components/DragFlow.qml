import QtQuick
import ".."

// Which tile in a Flow of variously sized widgets a point is nearest
// to, for a drag that swaps two tiles on drop rather than inserting one
// among the others the way DragList's rows do. A desktop's widgets are
// not an ordered list read top to bottom; dropping one on another just
// trades their two places and leaves everyone else exactly where they
// were.
Item {
    id: root

    // One entry per tile, in order: { width: real, height: real }.
    property var sizes: []
    property real maxWidth: 0
    property real spacing: 0

    // The tile being dragged and the one it is over now, both -1 when
    // nothing is happening.
    property int from: -1
    property int to: -1

    readonly property bool dragging: root.from >= 0

    signal swapped(int from, int to)

    // Left to right, wrapping to a new row when a tile would cross
    // maxWidth - the same rule Flow itself packs by, done here as data
    // so a tile's centre can be asked for without an actual Flow.
    function _pack(): var {
        const out = [];
        let x = 0, y = 0, rowH = 0;
        for (let i = 0; i < root.sizes.length; i++) {
            const s = root.sizes[i] ?? { width: 0, height: 0 };
            if (x > 0 && x + s.width > root.maxWidth) {
                x = 0;
                y += rowH + root.spacing;
                rowH = 0;
            }
            out[i] = { x: x, y: y, w: s.width, h: s.height };
            x += s.width + root.spacing;
            rowH = Math.max(rowH, s.height);
        }
        return out;
    }

    readonly property var _layout: root._pack()

    // Nearest tile centre to a point - the one being dragged included,
    // so hovering back over where it started answers with its own
    // index and drop() below is correctly a no-op.
    function nearestIndex(px: real, py: real): int {
        let best = 0, bestD = Infinity;
        for (let i = 0; i < root._layout.length; i++) {
            const r = root._layout[i];
            const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
            const d = (cx - px) * (cx - px) + (cy - py) * (cy - py);
            if (d < bestD) { bestD = d; best = i; }
        }
        return best;
    }

    // Called on release. Clears the drag first so a binding that reads
    // from/to sees "nothing happening" before the model changes under it.
    function drop(): void {
        const f = root.from;
        const t = root.to;
        root.from = -1;
        root.to = -1;
        if (f >= 0 && t >= 0 && f !== t)
            root.swapped(f, t);
    }
}
