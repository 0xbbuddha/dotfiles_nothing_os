import QtQuick
import "../../services"
import "draw.js" as D

// Three named gauges, not concentric rings: on 25 dots, three nested
// circles cannot be read (which is CPU?) and the GPU in the centre
// vanishes. A letter + a bar, like the settings DotSliders, stays
// readable in the disc.
QtObject {
    id: root

    readonly property int tick: 2000
    signal dirty()

    function meter(f: var, y: int, label: string, value: real, warn: bool): void {
        D.small(f, 3, y, label, warn ? 1 : 0.9, warn);
        const n = 12;
        const lit = Math.round(Math.max(0, Math.min(1, value)) * n);
        for (let row = 0; row < 2; row++) {
            for (let i = 0; i < n; i++) {
                const on = i < lit;
                const head = on && i === lit - 1;
                D.set(f, 9 + i, y + 1 + row, on ? 1 : 0.16, warn && (head || value > 0.85));
            }
        }
    }

    function render(f: var): void {
        const rows = [
            { l: "C", v: Sys.cpu, w: Sys.cpu > 0.85 || Sys.cpuTemp >= 80 }
        ];
        rows.push({ l: "R", v: Sys.ram, w: Sys.ram > 0.9 });
        if (Sys.gpuSeen)
            rows.push({ l: "G", v: Sys.gpu, w: Sys.gpuTemp >= 85 });

        const ys = rows.length === 3 ? [4, 10, 16] : [6, 13];
        for (let i = 0; i < rows.length; i++)
            root.meter(f, ys[i], rows[i].l, rows[i].v, rows[i].w);
    }
}
