pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The battery, named once.
//
// Called Batt, not Battery: the glyph surfaces already have a Battery
// component, and a singleton of the same name silently wins the import in
// every file that can see both. That took down the whole shell with
// "Composite Singleton Type Battery is not creatable", from a file that
// had never heard of this one.
//
// The bar reached straight into UPower.displayDevice and read six fields
// off it at each call site. That was fine while the bar was the only
// reader; with widgets wanting the same numbers it is two places deciding
// what "charging" means, so the reading lives here and both use it.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    // A desktop reports a fictional battery. Everything downstream keys on
    // this rather than on the percentage, because a machine with no
    // battery still cheerfully reports 100 %.
    readonly property bool present: device?.isLaptopBattery ?? false

    readonly property real fraction: Math.max(0, Math.min(1, device?.percentage ?? 0))
    readonly property int percent: Math.round(root.fraction * 100)

    readonly property bool charging:
        device?.state === UPowerDeviceState.Charging
    readonly property bool full:
        device?.state === UPowerDeviceState.FullyCharged

    // Watts in or out. UPower signs it; the direction is already in
    // `charging`, so this is the magnitude.
    readonly property real watts: Math.abs(device?.changeRate ?? 0)

    // Seconds. Zero means UPower does not know yet, which happens for a
    // minute or so after plugging in and must not be shown as "0 min".
    readonly property real secondsLeft: root.charging
        ? (device?.timeToFull ?? 0)
        : (device?.timeToEmpty ?? 0)

    readonly property bool knowsTime: root.secondsLeft > 0

    // Design capacity against what the cell holds now. Absent on some
    // firmware, hence the guard rather than a bare division.
    readonly property bool knowsHealth:
        isFinite(device?.energyCapacity ?? NaN) && (device?.energyCapacity ?? 0) > 0
    readonly property int health: root.knowsHealth
        ? Math.round(device.energyCapacity) : 0

    readonly property bool low: root.present && !root.charging && root.percent <= 20

    function pretty(sec: real): string {
        if (!isFinite(sec) || sec <= 0)
            return "--";
        const m = Math.round(sec / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? h + "H " + (m % 60) + "M" : m + "M";
    }
}
