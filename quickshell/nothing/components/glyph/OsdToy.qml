import QtQuick
import "../../services"
import "draw.js" as D

// Temporary overlay on the disc: volume, mute, brightness, charge.
// Not a catalogue toy — OsdPulse holds it in front of the current one.
QtObject {
    id: root

    readonly property int tick: (OsdPulse.shown && OsdPulse.mode === "charge") ? 50 : 0
    signal dirty()

    property var _pulse: Connections {
        target: OsdPulse
        function onShownChanged(): void { root.dirty(); }
        function onModeChanged(): void { root.dirty(); }
        function onDisplayChanged(): void { root.dirty(); }
        function onMutedChanged(): void { root.dirty(); }
    }

    function pct(v: real): string {
        return String(Math.round(Math.max(0, Math.min(1, v)) * 100));
    }

    function render(f: var): void {
        const mode = OsdPulse.mode;
        const v = Math.max(0, Math.min(1, OsdPulse.display));
        const muted = mode === "volume" && OsdPulse.muted;

        if (muted) {
            D.circle(f, 10.5, 1.6, 0.35, true);
            D.cross(f, 1, true);
            return;
        }

        if (mode === "keyboard") {
            D.circle(f, 11.2, 1.2, 0.22, false);
            D.ring(f, v, 10.5, 1.8, 1, false);
            D.smallCentered(f, 10, root.pct(v), 1, false);
            return;
        }

        if (mode === "brightness") {
            D.circle(f, 11.2, 1.2, 0.22, false);
            D.disc(f, D.center(f), D.center(f), 1.2 + v * 8.5, 1, false);
            D.smallCentered(f, 10, root.pct(v), 1, false);
            return;
        }

        if (mode === "charge") {
            const pulse = 0.62 + 0.38 * Math.sin(Date.now() / 180);
            D.circle(f, 10.5, 1.6, 0.18, false);
            D.ring(f, v, 10.5, 1.8, pulse, true);
            D.smallCentered(f, 10, OsdPulse.present ? root.pct(OsdPulse.charge) : "AC", 1, false);
            return;
        }

        D.waves(f, v, 1, false);
        D.smallCentered(f, 10, root.pct(v), 1, false);
    }
}
