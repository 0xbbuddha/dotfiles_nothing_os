import QtQuick
import "draw.js" as D

// Decorative oscillation, with a trail of previous positions.
// No interaction: right-click does nothing; scrolling changes toy.
QtObject {
    id: root

    property var trail: []
    readonly property int tick: 33
    signal dirty()

    function render(f: var): void {
        const c = D.center(f);
        const t = Date.now() / 1000;
        const angle = 0.7 * Math.sin((2 * Math.PI * t) / 2.4);
        const len = 9;
        const bx = c + Math.sin(angle) * len;
        const by = c + 1.5 + Math.cos(angle) * len;

        const next = root.trail.concat([{ x: bx, y: by }]);
        if (next.length > 10)
            next.shift();
        root.trail = next;

        for (let i = 0; i < next.length; i++) {
            const p = next[i];
            const v = 0.12 + (i / next.length) * 0.55;
            D.disc(f, p.x, p.y, 1.1, v, false);
        }

        D.line(f, c, c - 3, bx, by, 0.45, false);
        D.disc(f, c, c - 3, 0.7, 0.6, false);
        D.disc(f, bx, by, 2.0, 1, false);
    }
}
