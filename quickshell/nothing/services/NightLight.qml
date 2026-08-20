pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"

// Blue-light filter via the hyprsunset daemon, driven by hyprctl.
// Process is not used: a `&` inside a Process is killed with the group,
// the daemon dies and only the Matrix changes colour.
Singleton {
    id: root

    readonly property bool available: probe.found
    property bool active: false
    property bool dndHeld: false

    // Software gamma (hyprsunset): 25–100. Below 100, the image goes
    // darker than the panel minimum. First phase of the Light slider,
    // as in the other rice.
    readonly property int gammaLowerLimit: 25
    property int gamma: 100
    signal gammaAdjusted()

    readonly property int fromMin: root.parseTime(Config.nightFrom)
    readonly property int toMin: root.parseTime(Config.nightTo)

    function parseTime(hhmm: string): int {
        const p = String(hhmm).split(":");
        return (parseInt(p[0]) || 0) * 60 + (parseInt(p[1]) || 0);
    }

    readonly property bool inSchedule: {
        const now = Time.now.getHours() * 60 + Time.now.getMinutes();
        return root.fromMin <= root.toMin
            ? (now >= root.fromMin && now < root.toMin)
            : (now >= root.fromMin || now < root.toMin);
    }

    Process {
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: probe.found = text.trim() === "yes"
        }
    }

    function ensureDaemon(): void {
        Quickshell.execDetached(["sh", "-c",
            "pidof hyprsunset >/dev/null || nohup hyprsunset >/dev/null 2>&1 &"]);
    }

    function apply(on: bool): void {
        if (!root.available)
            return;
        root.active = on;
        root.ensureDaemon();
        send.restart();
    }

    function setGamma(g: real): void {
        if (!root.available)
            return;
        const next = Math.round(Math.max(root.gammaLowerLimit, Math.min(100, g)));
        if (next === root.gamma)
            return;
        root.gamma = next;
        root.ensureDaemon();
        gammaSend.restart();
        root.gammaAdjusted();
    }

    Timer {
        id: send
        interval: 180
        onTriggered: {
            // No `identity`: that also resets gamma to 100 and breaks
            // the extra-dim phase of the Light slider.
            if (root.active) {
                Quickshell.execDetached([
                    "hyprctl", "hyprsunset", "temperature",
                    String(Config.nightTemperature)
                ]);
            } else {
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", "6500"]);
            }
            Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)]);
        }
    }

    Timer {
        id: gammaSend
        interval: 40
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)])
    }

    Process {
        running: true
        command: ["hyprctl", "hyprsunset", "gamma"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10);
                if (!isNaN(n))
                    root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, n));
            }
        }
    }

    function toggle(): void { root.apply(!root.active); }

    onInScheduleChanged: {
        if (!Config.nightAutomatic)
            return;
        if (root.inSchedule) {
            if (!root.active)
                root.apply(true);
            if (!Notifs.doNotDisturb) {
                Notifs.doNotDisturb = true;
                root.dndHeld = true;
            }
        } else {
            if (root.active)
                root.apply(false);
            if (root.dndHeld) {
                Notifs.doNotDisturb = false;
                root.dndHeld = false;
            }
        }
    }

    Component.onCompleted: {
        if (Config.nightAutomatic && root.inSchedule) {
            root.apply(true);
            if (!Notifs.doNotDisturb) {
                Notifs.doNotDisturb = true;
                root.dndHeld = true;
            }
        }
    }
}
