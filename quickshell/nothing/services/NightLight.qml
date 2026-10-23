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

    // Software gamma (hyprsunset): 25 to 100. Below 100, the image goes
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

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                probe.found = text.trim() === "yes";
                if (probe.found)
                    root.startup();
            }
        }
    }

    // Started only when something here needs it, and never twice: pidof
    // first. It starts already in the state it is about to be asked for,
    // so there is no flash of hyprsunset's own 6000 K default before the
    // first command lands. Arguments travel as $@, not inside the script.
    function ensureDaemon(): void {
        const args = root.active
            ? ["-t", String(root.kelvin)] : ["-i"];
        Quickshell.execDetached(["sh", "-c",
            "pidof hyprsunset >/dev/null || nohup hyprsunset \"$@\" >/dev/null 2>&1 &",
            "hyprsunset"].concat(args));
    }

    // The temperature actually used: the setting, clamped to the range the
    // panel offers (hyprsunset itself takes 1000 to 20000).
    readonly property int minKelvin: 2500
    readonly property int maxKelvin: 6500
    readonly property int kelvin: Math.max(root.minKelvin,
        Math.min(root.maxKelvin, Config.nightTemperature))

    function apply(on: bool): void {
        if (!root.available)
            return;
        root.active = on;
        root.commanded = true;
        root.ensureDaemon();
        root.resent = 0;
        send.restart();
    }

    // Live: the screen follows the slider while it moves (one hyprctl per
    // settled step, through the running daemon). Saved a moment after the
    // slider stops rather than on every step.
    function setTemperature(k: int): void {
        const next = Math.round(Math.max(root.minKelvin, Math.min(root.maxKelvin, k)) / 100) * 100;
        if (next === Config.nightTemperature)
            return;
        Config.nightTemperature = next;
        saveLater.restart();
        if (root.active && root.available) {
            root.resent = 0;
            send.restart();
        }
    }

    // A manual choice, remembered so "restore on login" has something to
    // restore. The schedule calls apply() directly and is not remembered.
    function setActive(on: bool): void {
        root.apply(on);
        if (Config.nightOn !== on) {
            Config.nightOn = on;
            saveLater.restart();
        }
    }

    // Colours and brightness exactly as the panel sends them.
    function neutral(): void {
        if (!root.available)
            return;
        root.setActive(false);
        root.setGamma(100);
    }

    Timer {
        id: saveLater
        interval: 600
        onTriggered: Config.save()
    }

    function setGamma(g: real): void {
        if (!root.available)
            return;
        const next = Math.round(Math.max(root.gammaLowerLimit, Math.min(100, g)));
        if (next === root.gamma)
            return;
        root.gamma = next;
        root.commanded = true;
        root.ensureDaemon();
        gammaSend.restart();
        root.gammaAdjusted();
    }

    Timer {
        id: send
        interval: 180
        onTriggered: {
            // `identity` for off: since hyprsunset 0.4 it only swaps the
            // colour matrix for the identity and keeps gamma (the matrix is
            // identity x gamma), so the extra-dim phase survives. Older
            // releases reset gamma with it, which is why this used to send
            // 6500 K, which is close to neutral but not neutral.
            if (root.active) {
                Quickshell.execDetached([
                    "hyprctl", "hyprsunset", "temperature", String(root.kelvin)
                ]);
            } else {
                Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
            }
            Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)]);
            check.restart();
        }
    }

    Timer {
        id: gammaSend
        interval: 40
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)])
    }

    // ── What the daemon says ──────────────────────────────────────────
    //
    // Commands are fire and forget, so whether they landed is read back:
    // a daemon started a moment ago may not be listening yet, and the
    // first command is then lost. One resend, then the panel says so.
    property bool daemonUp: false
    property int liveKelvin: 0
    property bool liveIdentity: true
    property bool checked: false
    property int resent: 0

    readonly property string status: {
        if (!root.available)
            return "hyprsunset is not installed";
        if (!root.checked)
            return "";
        if (!root.daemonUp)
            return root.active || root.gamma < 100
                ? "hyprsunset is not answering" : "hyprsunset is not running";
        return root.liveIdentity ? "Neutral colours" : root.liveKelvin + " K";
    }

    Timer {
        id: check
        interval: 450
        onTriggered: statusProbe.running = true
    }

    NProcess {
        id: statusProbe
        // A daemon that is not running is reported in the panel, not here.
        quiet: true
        // Three answers, one per line. A constant script: nothing in it
        // comes from a setting.
        command: ["sh", "-c",
            "hyprctl hyprsunset temperature; echo; hyprctl hyprsunset identity get; echo; hyprctl hyprsunset gamma; echo",
            "hyprsunset-status"]
        stdout: StdioCollector {
            onStreamFinished: root.readStatus(text)
        }
    }

    property bool firstStatus: true
    // Set by the first command sent from here; until then the daemon's own
    // state is adopted rather than corrected.
    property bool commanded: false

    function readStatus(text: string): void {
        const lines = String(text).split("\n").map(s => s.trim()).filter(s => s !== "");
        const k = parseInt(lines[0] ?? "", 10);
        const id = lines[1] ?? "";
        const g = parseFloat(lines[2] ?? "");
        root.checked = true;
        root.daemonUp = !isNaN(k) && (id === "true" || id === "false") && !isNaN(g);
        if (!root.daemonUp) {
            if (!root.firstStatus && root.resent < 1 && (root.active || root.gamma < 100)) {
                root.resent++;
                root.ensureDaemon();
                send.restart();
            }
            root.firstStatus = false;
            return;
        }
        root.liveKelvin = k;
        root.liveIdentity = id === "true";
        if (root.firstStatus && !root.commanded) {
            // Whatever was already running (your own exec-once included)
            // is the truth at start: a warm daemon reads as on.
            root.firstStatus = false;
            root.active = !root.liveIdentity && k < root.maxKelvin;
            root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, Math.round(g)));
            return;
        }
        const want = root.active ? root.kelvin : -1;
        const wrong = root.active ? (root.liveIdentity || Math.abs(k - want) > 50)
                                  : !root.liveIdentity;
        if (wrong && root.resent < 1) {
            root.resent++;
            send.restart();
        }
    }

    function toggle(): void { root.setActive(!root.active); }

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

    // Once hyprsunset is known to exist. This used to run from
    // Component.onCompleted, before the probe had answered, when apply()
    // still saw available = false and quietly did nothing: a session that
    // started inside the night-light hours stayed neutral until the next
    // boundary.
    function startup(): void {
        statusProbe.running = true;
        // Opt-in and off by default: login keeps doing what it did unless
        // "Restore on login" was switched on in SUPER+P.
        if (Config.nightRestore && Config.nightOn && !(Config.nightAutomatic && !root.inSchedule))
            root.apply(true);
        if (Config.nightAutomatic && root.inSchedule) {
            root.apply(true);
            if (!Notifs.doNotDisturb) {
                Notifs.doNotDisturb = true;
                root.dndHeld = true;
            }
        }
    }
}
