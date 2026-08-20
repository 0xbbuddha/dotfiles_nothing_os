import QtQuick
import "draw.js" as D

// Faces 1 to 6 in the classic pattern. Right-click rerolls, with a short
// animation that cycles faces before stopping.
QtObject {
    id: root

    property int face: 1
    property int rolling: 0
    readonly property int tick: root.rolling > 0 ? 45 : 0
    signal dirty()

    readonly property var pips: ({
        1: [[1, 1]],
        2: [[0, 0], [2, 2]],
        3: [[0, 0], [1, 1], [2, 2]],
        4: [[0, 0], [0, 2], [2, 0], [2, 2]],
        5: [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]],
        6: [[0, 0], [0, 1], [0, 2], [2, 0], [2, 1], [2, 2]]
    })

    function tap(): void {
        root.rolling = 14;
        root.dirty();
    }

    function render(f: var): void {
        if (root.rolling > 0) {
            root.face = 1 + Math.floor(Math.random() * 6);
            root.rolling--;
        }

        D.circle(f, 11.2, 1.2, 0.22, false);
        const spots = root.pips[root.face] ?? root.pips[1];
        for (let i = 0; i < spots.length; i++) {
            const x = 7 + spots[i][0] * 5;
            const y = 7 + spots[i][1] * 5;
            D.disc(f, x, y, 1.55, 1, false);
        }
    }
}
