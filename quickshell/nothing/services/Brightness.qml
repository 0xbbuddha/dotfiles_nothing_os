pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Brightness: panel, software gamma, keyboard backlight.
// The screen slider has two phases, like the other rice:
//   0–30 %  hyprsunset gamma (darker than the panel minimum)
//   30–100 % backlight
// Keys go through up()/down() to chain the two.
Singleton {
    id: root

    property real value: 1.0        // panel, 0..1
    property bool available: false
    readonly property real split: 0.3
    readonly property real hwFloor: 0.01
    readonly property bool extraDim: NightLight.available && NightLight.gamma < 100
    readonly property real combined: {
        if (!NightLight.available)
            return root.value;
        if (NightLight.gamma < 100) {
            const span = 100 - NightLight.gammaLowerLimit;
            return ((NightLight.gamma - NightLight.gammaLowerLimit) / span) * root.split;
        }
        return root.split + root.value * (1 - root.split);
    }

    property real kbdValue: 1.0     // keyboard, 0..1
    property bool kbdAvailable: false
    property string kbdDevice: ""
    property int kbdMax: 0

    signal changedExternally(string kind)

    function parseTriplet(text: string): var {
        const p = text.trim().split(",");
        // brightnessctl -m : device,class,current,percent%,max
        // sysfs watcher    : kind,device,current,max  (kind = backlight|kbd)
        // old watcher      : device,current,max
        if (p.length >= 5)
            return { kind: p[1] === "leds" ? "kbd" : "backlight", cur: parseInt(p[2], 10), max: parseInt(p[4], 10), name: p[0] };
        if (p.length >= 4 && (p[0] === "backlight" || p[0] === "kbd"))
            return { kind: p[0], cur: parseInt(p[2], 10), max: parseInt(p[3], 10), name: p[1] };
        if (p.length >= 3)
            return { kind: "backlight", cur: parseInt(p[1], 10), max: parseInt(p[2], 10), name: p[0] };
        return null;
    }

    function applyLine(text: string, notify: bool): void {
        const t = root.parseTriplet(text);
        if (!t || !t.max)
            return;
        const v = Math.max(0, Math.min(1, t.cur / t.max));
        if (t.kind === "kbd") {
            root.kbdAvailable = true;
            root.kbdDevice = t.name;
            root.kbdMax = t.max;
            if (Math.abs(v - root.kbdValue) < 0.002)
                return;
            root.kbdValue = v;
            if (notify)
                root.changedExternally("keyboard");
            return;
        }
        root.available = true;
        if (Math.abs(v - root.value) < 0.002)
            return;
        root.value = v;
        if (notify)
            root.changedExternally("screen");
    }

    NProcess {
        id: probe
        running: true
        command: ["brightnessctl", "-m", "--class", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: root.applyLine(text, false)
        }
    }

    NProcess {
        id: kbdProbe
        running: true
        command: ["sh", "-c", "brightnessctl -l -m --class leds 2>/dev/null | grep kbd_backlight | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.applyLine(text, false)
        }
    }

    NProcess {
        running: true
        command: ["python3", Quickshell.shellPath("../../scripts/watch-brightness.py")]
        stdout: SplitParser {
            onRead: (line) => root.applyLine(line, true)
        }
    }

    NProcess { id: setter }
    NProcess { id: kbdSetter }

    function set(v: real): void {
        const clamped = Math.max(0.01, Math.min(1, v));
        root.value = clamped;
        setter.running = false;
        setter.command = ["brightnessctl", "-q", "--class", "backlight", "set", Math.round(clamped * 100) + "%"];
        setter.running = true;
        root.changedExternally("screen");
    }

    function setKbd(v: real): void {
        if (!root.kbdAvailable || root.kbdMax < 1)
            return;
        const step = Math.round(Math.max(0, Math.min(1, v)) * root.kbdMax);
        const next = step / root.kbdMax;
        root.kbdValue = next;
        kbdSetter.running = false;
        kbdSetter.command = ["brightnessctl", "-q", "-d", root.kbdDevice, "set", String(step)];
        kbdSetter.running = true;
        root.changedExternally("keyboard");
    }

    // Keyboard backlight by steps, so a key press moves one notch of what
    // the hardware actually offers rather than a fixed percentage. Nothing
    // here knows any vendor: the device is whatever exposes kbd_backlight,
    // and on a machine with none these simply do nothing.
    function kbdUp(): void {
        if (!root.kbdAvailable || root.kbdMax < 1)
            return;
        const step = Math.round(root.kbdValue * root.kbdMax);
        root.setKbd(Math.min(root.kbdMax, step + 1) / root.kbdMax);
    }

    function kbdDown(): void {
        if (!root.kbdAvailable || root.kbdMax < 1)
            return;
        const step = Math.round(root.kbdValue * root.kbdMax);
        root.setKbd(Math.max(0, step - 1) / root.kbdMax);
    }

    function setCombined(v: real): void {
        const t = Math.max(0, Math.min(1, v));
        if (!NightLight.available) {
            root.set(t);
            return;
        }
        if (t >= root.split) {
            if (NightLight.gamma !== 100)
                NightLight.setGamma(100);
            root.set((t - root.split) / (1 - root.split));
            return;
        }
        if (root.value > root.hwFloor + 0.005)
            root.set(root.hwFloor);
        NightLight.setGamma(t / root.split * (100 - NightLight.gammaLowerLimit) + NightLight.gammaLowerLimit);
    }

    function up(): void {
        if (NightLight.available && NightLight.gamma < 100) {
            NightLight.setGamma(NightLight.gamma + 5);
            return;
        }
        setter.running = false;
        setter.command = ["brightnessctl", "-e4", "-n2", "--class", "backlight", "set", "5%+"];
        setter.running = true;
    }

    function down(): void {
        if (NightLight.available && (NightLight.gamma < 100 || root.value <= 0.02)) {
            if (root.value > 0.02) {
                root.set(root.hwFloor);
                return;
            }
            NightLight.setGamma(NightLight.gamma - 5);
            return;
        }
        setter.running = false;
        setter.command = ["brightnessctl", "-e4", "-n2", "--class", "backlight", "set", "5%-"];
        setter.running = true;
    }
}
