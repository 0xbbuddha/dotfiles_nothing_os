import QtQuick
import Quickshell.Services.UPower
import "draw.js" as D

// Charge ring, percentage in the centre. No battery (desktop): an "AC".
QtObject {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: (dev?.ready ?? false) && (dev?.percentage ?? -1) >= 0
    readonly property real charge: Math.max(0, Math.min(1, dev?.percentage ?? 0))
    readonly property bool charging: (dev?.state ?? 0) === UPowerDeviceState.Charging
    readonly property bool low: root.present && root.charge < 0.2 && !root.charging

    signal dirty()

    // The ring eases toward the real charge instead of snapping to it -
    // the phone's own Glyph Progress, watched filling rather than read
    // as a number that jumped. No child timer: QtObject has nowhere to
    // put one, and no other toy here needs one either - render() is
    // already called every tick, so advancing shown in there and
    // speeding tick up while it has not caught up is the same lever
    // Pendulum and Chrono already animate with.
    property real shown: root.charge
    readonly property bool animating: Math.abs(root.shown - root.charge) > 0.002
    readonly property int tick: root.animating ? 50 : 2000

    function render(f: var): void {
        const d = root.charge - root.shown;
        root.shown = Math.abs(d) < 0.003 ? root.charge : root.shown + d * 0.25;

        if (!root.present) {
            D.circle(f, 10.5, 1.6, 0.45, false);
            D.smallCentered(f, 10, "AC", 1, false);
            return;
        }
        D.circle(f, 10.5, 1.6, 0.18, false);
        D.ring(f, root.shown, 10.5, 1.8, 1, root.low || root.charging);
        const pct = String(Math.round(root.charge * 100));
        D.smallCentered(f, 10, pct, 1, root.low);
    }
}
