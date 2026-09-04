pragma Singleton

import QtQuick
import Quickshell
import ".."

// What the Glyph is saying, and why.
//
// Surface agnostic on purpose. The Bar and the Strip are different shapes
// of the same idea, only one can be on at a time, and both answer the same
// question: has something happened, and how far along is it. Keeping this
// in the Bar and copying it into the Strip would have been two definitions
// of "a notification arrived", which is how two surfaces end up disagreeing
// about the same event.
//
// Dark until something happens. An earlier version kept every segment on a
// continuous reading, and it was unusable: CPU and network move every tick,
// so the lamps animated constantly and the whole thing read as a fault
// light. A notification lamp that is always doing something has stopped
// being a notification lamp.
//
// Every source can be switched off on its own.
Singleton {
    id: root

    // Which surface is lit, if any. One at a time: they are the same object
    // on the phone, a Matrix or a Bar or a ring depending which you own.
    readonly property string surface: Config.glyphBarEnabled ? "bar"
        : (Config.glyphStripEnabled ? "strip"
        : (Config.glyphEnabled ? "matrix" : ""))

    // The Bar and the Strip only. The Matrix was wired in here for a
    // while and taken back out: it is a display that runs toys, not a
    // notification light, which is the split Nothing's own hardware has.
    // Its page carried six event switches, a rhythm composer and a list of
    // segments that described a bar it does not have.
    readonly property bool live:
        root.surface === "bar" || root.surface === "strip"

    // ── What can light it ─────────────────────────────────────────────
    // `rhythm` marks the ones that play a chosen pattern. The other three
    // are not events with a shape: the volume is a level and has to read as
    // one, recording is a state that lasts, and a reveal is a snapshot.
    // Offering them a rhythm would be offering a setting that does nothing.
    readonly property var sources: [
        { id: "volume",    label: "Volume",    rhythm: false,
          hint: "Fills as a gauge when the level changes" },
        { id: "notify",    label: "Notifications", rhythm: true,
          hint: "When something arrives" },
        { id: "recording", label: "Recording", rhythm: false,
          hint: "Red, while a screen capture runs" },
        { id: "battery",   label: "Power",     rhythm: true,
          hint: "On the charger going in or out, and when low" },
        { id: "media",     label: "Track change", rhythm: true,
          hint: "When the player moves on" },
        { id: "reveal",    label: "Click to read", rhythm: false,
          hint: "A click shows the readings below for a moment" }
    ]

    // Play a pattern now, ignoring whether its source is switched on, so
    // the panel can demonstrate one you are about to choose.
    function preview(patternId: string): void {
        fall.stop();
        root.event = "notify";
        root.play(patternId);
    }

    function wants(id: string): bool {
        return root.live
            && Config.glyphEventsOf(root.surface).indexOf(id) >= 0;
    }

    // Whether the Glyph has taken over telling you about something, so the
    // on-screen version can stand down.
    //
    // Tied to the individual source, not to the surface as a whole. Switch
    // off Volume and the OSD comes back, because otherwise turning a source
    // off would leave you with nothing telling you at all, which is a
    // strange thing for a switch labelled "Volume" to do.
    function replaces(id: string): bool {
        return root.live && Config.glyphQuietOf(root.surface)
            && root.wants(id);
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
        case "notifs":  return Math.min(1, Notifs.unread / 9);
        case "media":   return Player.hasLength
            ? Math.min(1, Player.position / Player.length) : 0;
        default:        return 0;
        }
    }

    // ── State ─────────────────────────────────────────────────────────
    //
    // "" is dark. Anything else is the one thing the Glyph is saying.
    property string event: ""
    property real eventValue: 0

    // Captured when a reveal starts and held for its duration. Read live,
    // the readings would jitter for the second and a half they are up,
    // which is the flicker this design exists to remove.
    property var snapshot: []

    // Held while a surface is being dragged: see GlyphBarWidget.
    property bool dragging: false

    function raise(kind: string, value: real): void {
        player.stop();
        root.frameKind = "level";
        root.frameZones = [];
        root.event = kind;
        root.eventValue = Math.max(0, Math.min(1, value));
        fall.restart();
    }

    // Play the rhythm chosen for this source.
    //
    // Not one hard-coded sweep any more. On the phone the rhythm is the
    // message: you learn that two short flashes is a message and a long
    // one is a call, and you stop looking at the screen. A single fill
    // animation for everything threw that away, and read as loading
    // rather than as being told something.
    function pulse(source: string): void {
        fall.stop();
        root.event = source;
        root.play(Config.glyphPattern(root.surface, source));
    }

    // ── Composed patterns ─────────────────────────────────────────────
    //
    // Yours, from the composer, alongside the nine that ship. Kept here
    // rather than in GlyphPatterns so that library stays a plain table
    // with no dependency on settings.
    readonly property var custom: Config.glyphCustom ?? []

    function customById(id: string): var {
        return root.custom.find(c => c.id === id) ?? null;
    }

    // Everything you can choose, built in first.
    readonly property var patterns: {
        void root.custom;
        return GlyphPatterns.all.concat(root.custom.map(
            c => ({ id: c.id, label: c.label, hint: "Yours", mine: true })));
    }

    function patternLabel(id: string): string {
        return (root.patterns.find(p => p.id === id)?.label) ?? id;
    }

    function stepsFor(id: string): var {
        const mine = root.customById(id);
        return mine ? mine.steps : GlyphPatterns.steps(id);
    }

    // ── The step player ───────────────────────────────────────────────
    property var frames: []
    property int frame: -1
    // How to read eventValue: fill up to it, light only the zone at it, or
    // light the groups named in frameZones.
    property string frameKind: "level"
    property var frameZones: []
    property int frameGroups: 1

    function play(patternId: string): void {
        player.stop();
        root.frames = root.stepsFor(patternId);
        root.frame = -1;
        root.advance();
    }

    function advance(): void {
        root.frame++;
        if (root.frame >= root.frames.length) {
            root.eventValue = 0;
            root.frameKind = "level";
            root.frameZones = [];
            root.event = "";
            return;
        }
        const f = root.frames[root.frame];
        root.eventValue = f.v ?? 0;
        root.frameKind = f.k ?? "level";
        root.frameZones = f.z ?? [];
        root.frameGroups = Math.max(1, f.g ?? 1);
        player.interval = Math.max(16, f.ms);
        player.restart();
    }

    Timer {
        id: player
        onTriggered: root.advance()
    }

    // How many readings the lit surface can show at once, and how many
    // pads the composer offers: the Strip has three arcs, the Bar six
    // segments, and a pad that lit half an arc would be a pad you cannot
    // see the effect of.
    readonly property int slots: root.surface === "strip" ? 3 : 6


    // Expand a group index onto a surface of `total` zones. Groups rather
    // than zones is what lets a rhythm composed on one surface play on
    // the other.
    function groupRange(group: int, groups: int, total: int): var {
        const from = Math.floor(group * total / groups);
        const to = Math.max(from + 1, Math.floor((group + 1) * total / groups));
        return { from: from, to: to };
    }

    function reveal(): void {
        const list = Config.glyphChannelsOf(root.surface);
        const out = [];
        for (let i = 0; i < root.slots; i++)
            out.push(root.reading(list[i] ?? "off"));
        root.snapshot = out;
        root.raise("reveal", 0);
    }

    Timer {
        id: fall
        interval: 1600
        onTriggered: root.event = ""
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
                root.pulse("battery");
            root.lastCharging = Batt.charging;
        }
        function onLowChanged(): void {
            if (root.wants("battery") && Batt.low)
                root.pulse("battery");
        }
    }

    property string lastTrack: ""
    Connections {
        target: Player
        function onTitleChanged(): void {
            const t = Player.title ?? "";
            if (root.wants("media") && t !== "" && t !== root.lastTrack)
                root.pulse("media");
            root.lastTrack = t;
        }
    }

    readonly property bool recording:
        root.wants("recording") && Recorder.recording

    // ── Brightness ────────────────────────────────────────────────────
    //
    // Three levels, as the hardware has. Values rather than a multiplier,
    // so the lowest is still legible on a bright wallpaper.
    readonly property var levels: [
        { on: 0.55, off: 0.05 },
        { on: 0.80, off: 0.07 },
        { on: 1.00, off: 0.10 }
    ]
    readonly property var level:
        root.levels[Config.glyphLevelOf(root.surface)]
}
