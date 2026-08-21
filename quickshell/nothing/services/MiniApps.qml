pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import ".."
import "../components/apps/expr.js" as Expr

// Essential Apps runtime. Specs live under ~/.local/share/nothing/apps;
// this singleton owns their state, their tick and their network reads.
//
// The state deliberately does not live in the views: an app can be shown
// in the panel and on the desktop at the same time, and two hosts each
// running the tick would count down twice as fast.
Singleton {
    id: root

    property var specs: []
    property int stamp: 0          // the list of apps changed
    property int pulse: 0          // state or fetched data changed
    property bool busy: false
    property string status: ""
    property string lastError: ""
    // Saved, but something was off: the endpoint never answered, say.
    property string note: ""
    // Set while a generation is being torn down on purpose, so the exit
    // is not reported as a failure.
    property bool cancelled: false

    // id -> live state object, id -> fetched payload, id -> last fetch (s)
    property var stateBag: ({})
    property var dataBag: ({})
    property var fetchAt: ({})
    property var pending: ({})     // ids whose state is waiting to be written

    readonly property string script: Quickshell.shellPath("../../scripts/essential-app.py")
    readonly property bool empty: root.specs.length === 0

    function envBackend(): var {
        return ["env", `NOTHING_MIND_BACKEND=${Config.mindBackend}`];
    }

    function specOf(id: string): var {
        const src = root.specs;
        for (let i = 0; i < src.length; i++) {
            if (src[i].id === id)
                return src[i];
        }
        return null;
    }

    function stateOf(id: string): var {
        root.pulse;
        return root.stateBag[id] ?? ({});
    }

    function dataOf(id: string): var {
        root.pulse;
        return root.dataBag[id] ?? null;
    }

    // ── Shared halves of the expression context ──────────────────────
    // Each is a binding, so a spec reading time.epoch re-renders on the
    // second and one reading sys.cpu re-renders when the sampler fires.

    readonly property var timeCtx: {
        const d = Time.now;
        return {
            h: d.getHours(), m: d.getMinutes(), s: d.getSeconds(),
            hhmm: Time.hhmm,
            day: parseInt(Time.dayNum) || d.getDate(),
            dayShort: Time.dayShort,
            dateLong: Time.dateLong,
            week: Time.weekNumber,
            epoch: Math.floor(d.getTime() / 1000),
            iso: d.toISOString()
        };
    }

    readonly property var weatherCtx: ({
        temp: Weather.temp, hi: Weather.hi, lo: Weather.lo,
        desc: Weather.desc, city: Weather.city, ready: Weather.ready
    })

    readonly property var sysCtx: ({
        cpu: Sys.cpu, ram: Sys.ram, gpu: Sys.gpu,
        cpuTemp: Sys.cpuTemp, gpuTemp: Sys.gpuTemp
    })

    readonly property var mediaCtx: ({
        title: Player.cleanTitle, artist: Player.artist,
        album: Player.album, playing: Player.playing, active: Player.active
    })

    // `mode` and `signal` are kept as aliases: a model asked for a network
    // widget reaches for those names before it reaches for ours.
    readonly property var netCtx: ({
        kind: Net.kind, name: Net.name, strength: Net.strength,
        mode: Net.kind, signal: Net.strength, wifi: Net.wifiEnabled
    })

    // Read-only windows onto the rest of the shell. Curated on purpose:
    // an app gets facts, never a handle it could act through.
    readonly property var audioCtx: ({
        volume: Audio.volume, muted: Audio.muted,
        micMuted: Audio.micMuted, hasMic: Audio.hasMic
    })

    readonly property var batteryCtx: {
        const dev = UPower.displayDevice;
        const ready = (dev?.ready ?? false) && (dev?.percentage ?? -1) >= 0;
        return {
            present: ready,
            percent: ready ? Math.round((dev.percentage ?? 0) * 100) : 0,
            charge: ready ? (dev.percentage ?? 0) : 0,
            charging: (dev?.state ?? 0) === UPowerDeviceState.Charging
        };
    }

    readonly property var updatesCtx: ({
        count: Updates.count, urgent: Updates.urgent,
        available: Updates.available
    })

    readonly property var notifsCtx: ({
        unread: Notifs.unread, dnd: Notifs.doNotDisturb,
        count: (Notifs.history ?? []).length
    })

    readonly property var desktopCtx: ({
        workspace: Hyprland.focusedWorkspace?.name ?? "",
        monitor: Hyprland.focusedMonitor?.name ?? "",
        window: Hyprland.activeToplevel?.title ?? ""
    })

    readonly property var vaultCtx: {
        Essentials.stamp;
        const items = Essentials.items ?? [];
        const today = Time.now.toISOString().slice(0, 10);
        let count = 0;
        for (let i = 0; i < items.length; i++) {
            if (String(items[i].at ?? "").slice(0, 10) === today)
                count++;
        }
        const first = items.length > 0 ? items[0] : null;
        return {
            count: items.length,
            today: count,
            latest: first ? (first.title || first.summary
                || String(first.text ?? "").slice(0, 60) || first.kind || "") : ""
        };
    }

    function ctxFor(spec: var): var {
        return {
            state: root.stateBag[spec.id] ?? ({}),
            data: root.dataBag[spec.id] ?? null,
            time: root.timeCtx,
            weather: root.weatherCtx,
            sys: root.sysCtx,
            media: root.mediaCtx,
            net: root.netCtx,
            vault: root.vaultCtx,
            audio: root.audioCtx,
            battery: root.batteryCtx,
            updates: root.updatesCtx,
            notifs: root.notifsCtx,
            desktop: root.desktopCtx
        };
    }

    // ── Steps ────────────────────────────────────────────────────────

    function coerce(spec: var, key: string, value: var): var {
        // The declared default fixes the type: a field bound to a number
        // must not turn it into a string on the first keystroke.
        const proto = (spec.state ?? {})[key];
        if (typeof proto === "number") {
            const n = Number(value);
            return isFinite(n) ? n : 0;
        }
        if (typeof proto === "boolean")
            return !!value;
        return String(value ?? "").slice(0, 400);
    }

    function exec(spec: var, steps: var, item: var, index: int): bool {
        if (!spec || !Array.isArray(steps))
            return false;
        const st = root.stateBag[spec.id];
        if (!st)
            return false;
        const allowed = spec.state ?? {};
        const ctx = root.ctxFor(spec);
        let changed = false;

        for (let i = 0; i < steps.length; i++) {
            const step = steps[i];
            if (step.if !== undefined) {
                if (Expr.asBool(step.if, ctx, item, index))
                    changed = root.exec(spec, step.do, item, index) || changed;
                continue;
            }
            if (step.set !== undefined) {
                if (!(step.set in allowed))
                    continue;
                st[step.set] = root.coerce(spec, step.set,
                    Expr.evaluate(step.to, ctx, item, index));
                changed = true;
                continue;
            }
            if (step.inc !== undefined) {
                if (!(step.inc in allowed))
                    continue;
                const by = Expr.asNumber(step.by, ctx, item, index, 1);
                st[step.inc] = (Number(st[step.inc]) || 0) + by;
                changed = true;
                continue;
            }
            if (step.toggle !== undefined) {
                if (!(step.toggle in allowed))
                    continue;
                st[step.toggle] = !st[step.toggle];
                changed = true;
                continue;
            }
            if (step.notify !== undefined) {
                const title = Expr.asText(step.notify, ctx, item, index);
                if (title !== "")
                    Quickshell.execDetached(["notify-send", "-a", spec.name || "Essential Apps",
                        "-i", "applications-other", title,
                        Expr.asText(step.body ?? "", ctx, item, index)]);
                continue;
            }
            if (step.copy !== undefined) {
                const text = Expr.asText(step.copy, ctx, item, index);
                // argv, never `sh -c`: the value can come from a feed.
                if (text !== "")
                    Quickshell.execDetached(["wl-copy", "--", text]);
                continue;
            }
            if (step.open !== undefined) {
                const url = Expr.asText(step.open, ctx, item, index);
                if (/^https?:\/\//.test(url))
                    Quickshell.execDetached(["xdg-open", url]);
                continue;
            }
            if (step.refetch !== undefined) {
                root.fetchAt[spec.id] = 0;
                Qt.callLater(() => root.pumpFetch());
            }
        }
        return changed;
    }

    function run(id: string, action: string, item: var, index: int): void {
        const spec = root.specOf(id);
        if (!spec)
            return;
        const steps = (spec.actions ?? {})[action];
        if (!steps)
            return;
        if (root.exec(spec, steps, item ?? null, index ?? 0))
            root.commit(id);
    }

    function setKey(id: string, key: string, value: var): void {
        const spec = root.specOf(id);
        if (!spec || !(key in (spec.state ?? {})))
            return;
        const st = root.stateBag[id];
        if (!st)
            return;
        st[key] = root.coerce(spec, key, value);
        root.commit(id);
    }

    function commit(id: string): void {
        root.pulse++;
        root.pending[id] = true;
        saver.restart();
    }

    // ── Tick ─────────────────────────────────────────────────────────

    Timer {
        interval: 1000
        repeat: true
        running: root.specs.length > 0
        onTriggered: {
            let touched = false;
            const src = root.specs;
            for (let i = 0; i < src.length; i++) {
                const spec = src[i];
                if (!spec.tick || spec.tick.length === 0)
                    continue;
                if (root.exec(spec, spec.tick, null, 0)) {
                    touched = true;
                    root.pending[spec.id] = true;
                }
            }
            if (touched) {
                root.pulse++;
                saver.restart();
            }
            root.pumpFetch();
        }
    }

    // ── Network ──────────────────────────────────────────────────────
    // One curl at a time, driven by the tick. Apps only ever declare a
    // URL: the shell is what talks to the network, never the spec.

    function pumpFetch(): void {
        if (fetcher.running)
            return;
        const nowSec = Date.now() / 1000;
        const src = root.specs;
        for (let i = 0; i < src.length; i++) {
            const spec = src[i];
            if (!spec.fetch || !spec.fetch.url)
                continue;
            const last = root.fetchAt[spec.id] ?? 0;
            if (nowSec - last < (spec.fetch.every ?? 900))
                continue;
            root.fetchAt[spec.id] = nowSec;
            fetcher.appId = spec.id;
            fetcher.pickPath = spec.fetch.pick ?? "";
            fetcher.command = ["curl", "-sfLg", "--max-time", "12",
                               "-H", "Accept: application/json, application/vnd.api+json, */*",
                               "-A", "Mozilla/5.0 (compatible; nothing-essential-apps/1)", spec.fetch.url];
            fetcher.running = true;
            return;
        }
    }

    function refetch(id: string): void {
        root.fetchAt[id] = 0;
        root.pumpFetch();
    }

    Process {
        id: fetcher
        property string appId: ""
        property string pickPath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const id = fetcher.appId;
                if (id === "" || text.trim() === "")
                    return;
                try {
                    root.dataBag[id] = Expr.pick(JSON.parse(text), fetcher.pickPath);
                } catch (e) {
                    root.dataBag[id] = null;
                }
                root.pulse++;
            }
        }
        onExited: (code) => {
            // A failed read leaves the previous payload in place: a widget
            // that already showed something should not blank out on a
            // dropped connection.
            if (code !== 0 && root.dataBag[fetcher.appId] === undefined)
                root.dataBag[fetcher.appId] = null;
            Qt.callLater(() => root.pumpFetch());
        }
    }

    // ── Persistence ──────────────────────────────────────────────────
    // States are written through one process at a time; the tick would
    // otherwise spawn a python per second per running timer.

    Timer {
        id: saver
        interval: 1200
        onTriggered: root.flush()
    }

    function flush(): void {
        if (writer.running)
            return;
        for (const id in root.pending) {
            if (!root.pending[id])
                continue;
            delete root.pending[id];
            const st = root.stateBag[id];
            if (!st)
                continue;
            writer.payload = JSON.stringify(st);
            writer.running = false;
            writer.command = ["python3", root.script, "state", id];
            writer.stdinEnabled = true;
            writer.running = true;
            return;
        }
    }

    Process {
        id: writer
        property string payload: ""
        onRunningChanged: {
            if (running) {
                write(payload);
                stdinEnabled = false;
            }
        }
        onExited: Qt.callLater(() => root.flush())
    }

    // ── Library ──────────────────────────────────────────────────────

    function refresh(): void {
        lister.running = false;
        lister.command = ["python3", root.script, "list"];
        lister.running = true;
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    const data = JSON.parse(text);
                    list = Array.isArray(data) ? data : [];
                } catch (e) {
                    list = [];
                }
                const keptState = {};
                const keptData = {};
                for (let i = 0; i < list.length; i++) {
                    const spec = list[i];
                    const defaults = spec.state ?? {};
                    const saved = spec.saved ?? {};
                    const live = {};
                    for (const key in defaults)
                        live[key] = (key in saved) ? saved[key] : defaults[key];
                    keptState[spec.id] = live;
                    if (root.dataBag[spec.id] !== undefined)
                        keptData[spec.id] = root.dataBag[spec.id];
                }
                root.stateBag = keptState;
                root.dataBag = keptData;
                root.specs = list;
                root.stamp++;
                root.pulse++;
                Qt.callLater(() => root.pumpFetch());
            }
        }
    }

    // ── Creating and editing ─────────────────────────────────────────

    property string awaiting: ""   // id the panel should open once written

    function create(prompt: string): void {
        const text = (prompt ?? "").trim();
        if (text === "" || root.busy)
            return;
        root.busy = true;
        root.cancelled = false;
        root.status = "Writing the app";
        root.lastError = "";
        root.note = "";
        maker.payload = text;
        maker.running = false;
        maker.command = root.envBackend().concat(
            ["python3", root.script, "gen"]);
        maker.stdinEnabled = true;
        maker.running = true;
    }

    function refine(id: string, change: string): void {
        const text = (change ?? "").trim();
        if (id === "" || text === "" || root.busy)
            return;
        root.busy = true;
        root.cancelled = false;
        root.status = "Applying the change";
        root.lastError = "";
        root.note = "";
        maker.payload = text;
        maker.running = false;
        maker.command = root.envBackend().concat(
            ["python3", root.script, "refine", id]);
        maker.stdinEnabled = true;
        maker.running = true;
    }

    Process {
        id: maker
        property string payload: ""
        onRunningChanged: {
            if (running) {
                write(payload);
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.cancelled)
                    return;
                root.busy = false;
                let reply = null;
                try {
                    reply = JSON.parse(text);
                } catch (e) {
                    reply = null;
                }
                if (reply && reply.ok) {
                    root.status = "";
                    root.lastError = "";
                    root.note = reply.note ?? "";
                    root.awaiting = reply.id ?? "";
                    root.refresh();
                } else {
                    root.status = "";
                    root.lastError = (reply && reply.error)
                        ? reply.error : "The app could not be written";
                }
            }
        }
        onExited: (code) => {
            if (root.cancelled) {
                root.cancelled = false;
                return;
            }
            if (root.busy) {
                root.busy = false;
                root.status = "";
                if (root.lastError === "")
                    root.lastError = "The generator failed";
            }
        }
    }

    function put(id: string, json: string): void {
        root.busy = true;
        root.status = "Saving";
        root.lastError = "";
        maker.payload = json;
        maker.running = false;
        maker.command = ["python3", root.script, "put", id];
        maker.stdinEnabled = true;
        maker.running = true;
    }

    // A prompt can be wrong the moment it is sent, and a generation takes
    // the better part of a minute. Nothing is written until the very end,
    // so killing it mid-flight leaves no half-built app behind.
    function cancel(): void {
        if (!root.busy)
            return;
        root.cancelled = true;
        maker.running = false;
        root.busy = false;
        root.status = "";
        root.lastError = "";
        root.note = "Stopped";
    }

    function remove(id: string): void {
        delete root.stateBag[id];
        delete root.dataBag[id];
        Config.removeDeskApp(id);
        simple.running = false;
        simple.command = ["python3", root.script, "remove", id];
        simple.running = true;
    }

    function rename(id: string, name: string): void {
        simple.running = false;
        simple.command = ["python3", root.script, "rename", id, name];
        simple.running = true;
    }

    function reset(id: string): void {
        simple.running = false;
        simple.command = ["python3", root.script, "reset", id];
        simple.running = true;
    }

    function revert(id: string, version: int): void {
        simple.running = false;
        simple.command = ["python3", root.script, "revert", id, String(version)];
        simple.running = true;
    }

    function install(preset: string): void {
        simple.running = false;
        simple.command = ["python3", root.script, "install", preset];
        simple.running = true;
    }

    Process {
        id: simple
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    // Bundled presets, for the panel's second tab.
    property var presets: []

    Process {
        id: presetLister
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.presets = Array.isArray(data) ? data : [];
                } catch (e) {
                    root.presets = [];
                }
            }
        }
    }

    Process {
        id: seeder
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    Component.onCompleted: {
        seeder.command = ["python3", root.script, "seed"];
        seeder.running = true;
        presetLister.command = ["python3", root.script, "presets"];
        presetLister.running = true;
    }
}
