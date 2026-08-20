import QtQuick
import "draw.js" as D

// After the Glyph Toy: a useless counter, five dots that light in a loop.
// Right-click (or long-press) increments.
QtObject {
    id: root

    property int score: 0
    property int lit: 0
    readonly property int tick: 0
    signal dirty()

    function tap(): void {
        root.score++;
        root.lit = root.lit >= 5 ? 0 : root.lit + 1;
        root.dirty();
    }

    function render(f: var): void {
        const s = String(root.score);
        if (s.length <= 3)
            D.bigCentered(f, 5, s, 1, false);
        else
            D.smallCentered(f, 8, s, 1, false);

        const c = D.center(f);
        for (let i = 0; i < 5; i++) {
            const on = i < root.lit;
            D.disc(f, c + (i - 2) * 2.4, 19.5, on ? 0.85 : 0.55, on ? 1 : 0.22, on);
        }
    }
}
