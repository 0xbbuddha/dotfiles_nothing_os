import QtQuick
import Quickshell.Services.UPower
import "draw.js" as D

// Charge ring, percentage in the centre. No battery (desktop): an "AC".
QtObject {
    id: root

    readonly property int tick: 2000
    readonly property var dev: UPower.displayDevice
    readonly property bool present: (dev?.ready ?? false) && (dev?.percentage ?? -1) >= 0
    readonly property real charge: Math.max(0, Math.min(1, dev?.percentage ?? 0))
    readonly property bool charging: (dev?.state ?? 0) === UPowerDeviceState.Charging
    readonly property bool low: root.present && root.charge < 0.2 && !root.charging

    signal dirty()

    function render(f: var): void {
        if (!root.present) {
            D.circle(f, 10.5, 1.6, 0.45, false);
            D.smallCentered(f, 10, "AC", 1, false);
            return;
        }
        D.circle(f, 10.5, 1.6, 0.18, false);
        D.ring(f, root.charge, 10.5, 1.8, 1, root.low || root.charging);
        const pct = String(Math.round(root.charge * 100));
        D.smallCentered(f, 10, pct, 1, root.low);
    }
}
