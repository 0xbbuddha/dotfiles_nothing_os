pragma Singleton

import QtQuick
import Quickshell
import ".."

// What the Glyph Bar is showing, and why.
//
// The hardware, so the shape here is not invented: six segments stacked
// beside the camera island, a seventh that lights only while the camera is
// recording, and sixty-three mini-LEDs under the six, which is nine each.
// Nine lamps in a square is a three by three grid.
//
// Dark until something happens. An earlier version kept each segment on a
// continuous reading, and it was unusable: CPU and network move every
// tick, so the lamps animated constantly and the whole strip read as a
// fault light. A notification lamp that is always doing something has
// stopped being a notification lamp.
//
// Every source can be switched off on its own. A bar that insists on
// telling you about the battery when you only wanted the volume is the
// same problem in a smaller form.
Singleton {
    id: root

    readonly property int segments: 6
    readonly property int lamps: 9
    readonly property int side: 3

    // Geometry, named once. The strip lays itself out from these and the
    // plate around it sizes itself from the same numbers, so the black
    // never ends up with a margin the lamps do not fill.
    readonly property real gap: 0.17          // of a segment
    readonly property real aspect: 7 + 6 * root.gap

    // Three levels, as the hardware has. Values rather than a multiplier,
    // so the lowest is still legible on a bright wallpaper.
    readonly property var levels: [
        { on: 0.55, off: 0.05 },
        { on: 0.80, off: 0.07 },
        { on: 1.00, off: 0.10 }
    ]
    readonly property var level:
        root.levels[Math.max(0, Math.min(2, Config.glyphBarLevel))]

    // ── What can light it ─────────────────────────────────────────────
    readonly property var sources: [
        { id: "volume",    label: "Volume",
          hint: "Fills as a gauge when the level changes" },
        { id: "notify",    label: "Notifications",
          hint: "Sweeps once and drains" },
        { id: "recording", label: "Recording",
          hint: "The seventh segment, red, while capture runs" },
        { id: "battery",   label: "Power",
          hint: "On the charger going in or out, and when low" },
        { id: "media",     label: "Track change",
          hint: "A sweep when the player moves on" },
        { id: "reveal",    label: "Click to read",
          hint: "A click shows the readings below for a moment" }
    ]

    function wants(id: string): bool {
        return Config.glyphBarEnabled
            && (Config.glyphBarEvents ?? []).indexOf(id) >= 0;
    }

    // ── What a segment shows during a reveal ──────────────────────────
    readonly property var channels: [
        { id: "battery", label: "Battery",  hint: "Charge remaining" },
        { id: "volume",  label: "Volume",   hint: "Output level" },
        { id: "cpu",     label: "CPU",      hint: "Load right now" },
        { id: "ram",     label: "Memory",   hint: "In use" },
        { id: "net",     label: "Network",  hint: "Coming down" },
        { id: "notifs",  label: "Notices",  hint: "Unread, one lamp each" },
        { id: "media",   label: "Playing",  hint: "Position in the track" },
        { id: "off",     label: "Off",      hint: "Stays dark" }
    ]

    function channelLabel(id: string): string {
        return (root.channels.find(c => c.id === id)?.label) ?? id;
    }

    function reading(id: string): real {
        switch (id) {
        case "battery": return Batt.present ? Batt.fraction : 0;
        case "volume":  return Audio.muted ? 0 : Audio.volume;
        case "cpu":     return Sys.cpu;
        case "ram":     return Sys.ram;
        // Logarithmic: the interesting range spans four orders of
        // magnitude, and linear stays dark until it suddenly is not.
        case "net":     return Netflow.ready
            ? Math.min(1, Math.log(1 + Netflow.rx / 1024) / Math.log(1 + 8192))
            : 0;
        case "notifs":  return Math.min(1, Notifs.unread / root.lamps);
        case "media":   return Player.hasLength
            ? Math.min(1, Player.position / Player.length) : 0;
        default:        return 0;
        }
    }

    // ── State ─────────────────────────────────────────────────────────
    //
    // "" is dark. Anything else is the one thing the bar is saying.
    property string event: ""
    property real eventValue: 0

    // Held by whichever surface is being dragged. The bar swaps between a
    // desktop-layer surface and an above-windows one to rise for an event,
    // and doing that mid-drag would unmap the window under the cursor.
    // Central rather than per-window, because the window that must not
    // vanish is not the one that would notice.
    property bool dragging: false

    // Captured when a reveal starts and held for its duration. Read live,
    // the readings would jitter for the second and a half they are up,
    // which is the flicker this design exists to remove.
    property var snapshot: []

    function raise(kind: string, value: real): void {
        sweep.stop();
        root.event = kind;
        root.eventValue = Math.max(0, Math.min(1, value));
        fall.restart();
    }

    // A sweep fills and drains, rather than sitting at full for a second
    // and a half. That is the shape of the phone's own notification.
    function pulse(kind: string): void {
        fall.stop();
        root.event = kind;
        sweep.restart();
    }

    function reveal(): void {
        const list = Config.glyphBarChannels ?? [];
        const out = [];
        for (let i = 0; i < root.segments; i++)
            out.push(root.reading(list[i] ?? "off"));
        root.snapshot = out;
        root.raise("reveal", 0);
    }

    Timer {
        id: fall
        interval: 1600
        onTriggered: root.event = ""
    }

    SequentialAnimation {
        id: sweep
        NumberAnimation {
            target: root; property: "eventValue"
            from: 0; to: 1; duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "eventValue"
            to: 0; duration: 700
            easing.type: Easing.InCubic
        }
        ScriptAction { script: root.event = ""; }
    }

    // ── Sources ───────────────────────────────────────────────────────
    Connections {
        target: Audio
        enabled: root.wants("volume")
        function onVolumeChanged(): void {
            root.raise("volume", Audio.muted ? 0 : Audio.volume);
        }
        function onMutedChanged(): void {
            root.raise("volume", Audio.muted ? 0 : Audio.volume);
        }
    }

    property int lastUnread: 0
    Connections {
        target: Notifs
        function onUnreadChanged(): void {
            const n = Notifs.unread;
            // Tracked even when the source is off, or switching it back on
            // would fire once for everything that arrived meanwhile.
            if (root.wants("notify") && n > root.lastUnread)
                root.pulse("notify");
            root.lastUnread = n;
        }
    }

    property bool lastCharging: false
    Connections {
        target: Batt
        function onChargingChanged(): void {
            if (root.wants("battery") && Batt.present
                    && Batt.charging !== root.lastCharging)
                root.pulse("notify");
            root.lastCharging = Batt.charging;
        }
        function onLowChanged(): void {
            if (root.wants("battery") && Batt.low)
                root.pulse("notify");
        }
    }

    property string lastTrack: ""
    Connections {
        target: Player
        function onTitleChanged(): void {
            const t = Player.title ?? "";
            if (root.wants("media") && t !== "" && t !== root.lastTrack)
                root.pulse("notify");
            root.lastTrack = t;
        }
    }

    // The seventh. The only red on the bar, exactly as the recording light
    // is the only red on the phone.
    readonly property bool recording:
        root.wants("recording") && Recorder.recording
}
