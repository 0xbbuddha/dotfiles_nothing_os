import QtQuick
import "draw.js" as D

// Stopwatch and timer. Right-click: start / stop. Wheel when stopped:
// set the countdown in 30-second steps (zero = stopwatch).
//
// The file is not named Timer.qml: importing the glyph folder would
// otherwise shadow QtQuick's Timer.
QtObject {
    id: root

    property bool running: false
    property int elapsedMs: 0
    property int targetMs: 0
    property var startedAt: 0
    property bool alarmed: false

    readonly property bool wheel: true
    readonly property int tick: root.running ? 200 : 0
    signal dirty()

    function shownMs(): int {
        const elapsed = root.running
            ? root.elapsedMs + (Date.now() - root.startedAt)
            : root.elapsedMs;
        if (root.targetMs > 0)
            return Math.max(0, root.targetMs - elapsed);
        return Math.max(0, elapsed);
    }

    function tap(): void {
        if (root.running) {
            root.elapsedMs = root.elapsedMs + (Date.now() - root.startedAt);
            root.running = false;
            if (root.targetMs > 0 && root.elapsedMs >= root.targetMs) {
                root.elapsedMs = 0;
                root.alarmed = true;
            }
        } else {
            if (root.alarmed) {
                root.alarmed = false;
                root.elapsedMs = 0;
            }
            root.startedAt = Date.now();
            root.running = true;
        }
        root.dirty();
    }

    function scroll(delta: real): void {
        if (root.running)
            return;
        const step = 30 * 1000;
        if (delta > 0)
            root.targetMs += step;
        else if (root.targetMs > 0)
            root.targetMs = Math.max(0, root.targetMs - step);
        else
            root.elapsedMs = 0;
        root.elapsedMs = 0;
        root.alarmed = false;
        root.dirty();
    }

    function render(f: var): void {
        let ms = root.shownMs();
        if (root.running && root.targetMs > 0 && ms <= 0) {
            root.running = false;
            root.elapsedMs = 0;
            root.alarmed = true;
            ms = 0;
        }

        const total = Math.floor(ms / 1000);
        const mm = String(Math.floor(total / 60) % 100).padStart(2, "0");
        const ss = String(total % 60).padStart(2, "0");
        const accent = root.alarmed || (root.targetMs > 0 && root.running && ms < 10000);

        if (root.targetMs > 0) {
            const p = ms / root.targetMs;
            D.circle(f, 11.2, 1.2, 0.16, false);
            D.ring(f, p, 11.2, 1.6, 1, accent);
        }

        D.bigCentered(f, 5, mm, 1, accent);
        D.bigCentered(f, 13, ss, 1, accent);
    }
}
