pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import ".."

// Volume, brightness, mute and charge: one pulse, two views
// (Glyph Matrix when it is on, otherwise the bottom pill).
Singleton {
    id: root

    property bool armed: false
    property bool shown: false
    property string mode: "volume"   // volume | brightness | keyboard | charge
    property real display: 0
    property bool animate: true

    readonly property var batt: UPower.displayDevice
    readonly property bool present: (batt?.ready ?? false) && (batt?.percentage ?? -1) >= 0
    readonly property real charge: Math.max(0, Math.min(1, batt?.percentage ?? 0))
    readonly property bool charging: (batt?.state ?? 0) === UPowerDeviceState.Charging
    property bool sawCharge: false

    readonly property bool muted: Audio.muted
    readonly property real level: {
        if (root.mode === "volume")
            return root.muted ? 0 : Audio.volume;
        if (root.mode === "keyboard")
            return Brightness.kbdValue;
        if (root.mode === "charge")
            return root.charge;
        return Brightness.combined;
    }

    Behavior on display {
        enabled: root.animate
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function flash(which: string): void {
        if (!root.armed || !Config.osdEnabled)
            return;
        // The Glyph Bar shows the volume as a gauge across its segments,
        // so the pill in the middle of the screen is the same reading
        // twice.
        if (which === "volume" && GlyphBar.replaces("volume"))
            return;
        root.mode = which;
        root.shown = true;
        if (which === "charge") {
            root.animate = false;
            root.display = 0;
            root.animate = true;
            sweep.restart();
        } else {
            root.display = root.level;
        }
        hide.interval = which === "charge" ? 2200 : 1600;
        hide.restart();
    }

    onLevelChanged: {
        if (root.shown && root.mode !== "charge")
            root.display = root.level;
    }

    Timer { interval: 1500; running: true; onTriggered: {
        root.sawCharge = root.charging;
        root.armed = true;
    } }
    Timer { id: hide; interval: 1600; onTriggered: root.shown = false }
    Timer { id: sweep; interval: 16; onTriggered: root.display = root.level }

    Connections {
        target: Audio
        function onVolumeChanged(): void { root.flash("volume"); }
        function onMutedChanged(): void { root.flash("volume"); }
    }

    Connections {
        target: Brightness
        function onChangedExternally(kind): void {
            root.flash(kind === "keyboard" ? "keyboard" : "brightness");
        }
    }

    Connections {
        target: NightLight
        function onGammaAdjusted(): void { root.flash("brightness"); }
    }

    onChargingChanged: {
        if (!root.armed) {
            root.sawCharge = root.charging;
            return;
        }
        if (root.charging && !root.sawCharge)
            root.flash("charge");
        root.sawCharge = root.charging;
    }
}
