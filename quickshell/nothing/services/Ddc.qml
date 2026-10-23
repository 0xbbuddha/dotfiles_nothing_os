pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// External monitors' own brightness, over DDC/CI with ddcutil.
//
// This is the monitor's backlight, the same thing its OSD buttons move,
// and it has nothing to do with hyprsunset's gamma: that one darkens the
// picture in software and stays in NightLight.
//
// Monitors are addressed by I2C bus, never by ddcutil's display number:
// the number is the order detection happened to find them in, and the
// bus is tied to the cable. The bus is matched to Hyprland's output name
// through the DRM connector ddcutil reports (card1-DP-1 is DP-1).
//
// DDC/CI is slow (a read is a few hundred ms) and some monitors take a
// moment to admit a change, so:
//   - every call goes through one worker, one at a time, because two
//     ddcutil processes talking on the same bus confuse each other;
//   - a slider only records what it wants, and the worker writes the
//     latest value once it is free, so a drag is one or two writes and
//     never a backlog, and the last value moved to is the one written;
//   - writes are done with --noverify and then read back here, twice,
//     with a pause, because a monitor that is slow to report (the source
//     of DDCRC_VERIFY) is not the same as one that refused. A value that
//     still reads wrong after one more write is reported as refused, and
//     that screen gets no more writes until you ask it to try again.
//
// Nothing here runs until the panel asks: no polling, no probing at login.
Singleton {
    id: root

    property bool available: false      // ddcutil is installed
    property bool probed: false
    property bool detecting: false
    property bool detected: false
    // A problem with DDC as a whole (permissions, i2c-dev), not one screen.
    property string fault: ""

    // From `ddcutil detect`: [{ bus, connector, model, mfg, ok, reason }]
    property var monitors: []

    // Per bus: { cur, max, want, target, status, error, blocked }
    //   status: "unknown" | "reading" | "writing" | "verifying" | "ok" | "error"
    property var state: ({})

    readonly property int settleFirst: 400
    readonly property int settleSecond: 1200
    readonly property int maxWrites: 2
    readonly property int timeoutMs: 12000

    function forBus(bus: int): var {
        return root.state[bus] ?? null;
    }

    function byConnector(name: string): var {
        return root.monitors.find(m => m.connector === name) ?? null;
    }

    function patch(bus: int, fields: var): void {
        const next = Object.assign({}, root.state);
        next[bus] = Object.assign({ cur: -1, max: 100, want: -1, target: -1,
                                    status: "unknown", error: "", blocked: false },
                                  next[bus] ?? {}, fields);
        root.state = next;
    }

    // ── Probing and detection ─────────────────────────────────────────
    NProcess {
        id: probe
        // Absent is an answer, not a fault.
        quiet: true
        command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                root.probed = true;
                if (root.available && root.wantDetect)
                    root.detect();
            }
        }
    }

    property bool wantDetect: false

    // Called when the panel's Light page opens. Detection is a couple of
    // seconds of I2C traffic, so it happens once, and again on request.
    function ensure(): void {
        if (root.detected || root.detecting)
            return;
        root.wantDetect = true;
        if (!root.probed) {
            if (!probe.running)
                probe.running = true;
            return;
        }
        if (root.available)
            root.detect();
    }

    function detect(): void {
        if (!root.available)
            return;
        root.wantDetect = false;
        root.detecting = true;
        root.fault = "";
        // Pending brightness reads are redone after detection; queued
        // capability and feature reads are kept, or a card opened just
        // before a refresh would wait for them forever.
        root.queue = root.queue.filter(j => j.kind === "caps" || j.kind === "fread");
        root.enqueue({ kind: "detect" }, true);
    }

    // Re-detect and re-read everything, and lift any block: this is the
    // "try again" a refused screen waits for. It only reads; a monitor's
    // brightness is never written by a refresh.
    function refresh(): void {
        const next = {};
        for (const k in root.state)
            next[k] = Object.assign({}, root.state[k], { blocked: false, error: "", want: -1 });
        root.state = next;
        root.detected = false;
        if (!root.probed) {
            root.ensure();
            return;
        }
        root.detect();
    }

    function retry(bus: int): void {
        root.patch(bus, { blocked: false, error: "", want: -1 });
        root.enqueue({ kind: "read", bus: bus }, false);
    }

    function parseDetect(text: string): var {
        const out = [];
        let cur = null;
        for (const raw of String(text).split("\n")) {
            const head = raw.match(/^(Display (\d+)|Invalid display|Phantom display)\s*$/);
            if (head) {
                cur = {
                    ok: head[2] !== undefined,
                    phantom: head[1].indexOf("Phantom") === 0,
                    bus: -1, connector: "", model: "", mfg: "", reason: ""
                };
                out.push(cur);
                continue;
            }
            if (!cur)
                continue;
            const line = raw.trim();
            let m;
            if ((m = line.match(/^I2C bus:\s+\/dev\/i2c-(\d+)/)))
                cur.bus = parseInt(m[1], 10);
            else if ((m = line.match(/^DRM[_ ]connector:\s+(\S+)/)))
                cur.connector = m[1].replace(/^card\d+-/, "");
            else if ((m = line.match(/^Mfg id:\s+(.+)$/)))
                cur.mfg = m[1].trim();
            else if ((m = line.match(/^Model:\s+(.+)$/)))
                cur.model = m[1].trim();
            else if (!cur.ok && cur.reason === ""
                     && /DDC|communication|not support|unsupported/i.test(line))
                cur.reason = line;
        }
        return out.filter(d => !d.phantom && d.bus >= 0);
    }

    // What is wrong when detection itself fails, in words that say what
    // to do about it. Nothing here runs sudo or changes permissions.
    function explain(err: string): string {
        if (/No \/dev\/i2c|i2c-dev.*not loaded|module i2c.dev/i.test(err))
            return "The i2c-dev kernel module is not loaded. Load it with "
                 + "`sudo modprobe i2c-dev`; to keep it, add i2c-dev to "
                 + "/etc/modules-load.d/i2c-dev.conf.";
        if (/permission denied|EACCES|not readable|not writable/i.test(err))
            return "No access to /dev/i2c-*. ddcutil's udev rule "
                 + "(60-ddcutil-i2c.rules) grants it to the logged-in user; "
                 + "check it is installed, then log in again.";
        return err.split("\n").map(s => s.trim()).find(s => s !== "") ?? "ddcutil failed";
    }

    // ── The worker ────────────────────────────────────────────────────
    property var queue: []
    property var job: null
    property int seq: 0
    property bool outDone: false
    property bool errDone: false
    property int exitCode: -999

    function enqueue(j: var, front: bool): void {
        const q = root.queue.slice();
        if (front)
            q.unshift(j);
        else
            q.push(j);
        root.queue = q;
        root.kick();
    }

    // Deferred, so a finished process is never restarted from inside its
    // own exit handler, and several requests in one turn start one job.
    function kick(): void {
        Qt.callLater(root.pump);
    }

    // Writes are not queued: each screen holds the value it wants, and
    // the latest one is turned into a write whenever the worker is free.
    function nextWrite(): var {
        for (const m of root.monitors) {
            if (!m.ok)
                continue;
            const st = root.state[m.bus];
            if (!st || st.blocked || st.want < 0)
                continue;
            return { kind: "write", bus: m.bus, value: st.want, tries: 1 };
        }
        return null;
    }

    function pump(): void {
        if (root.job !== null || wait.running)
            return;
        let j = null;
        if (root.queue.length > 0) {
            const q = root.queue.slice();
            j = q.shift();
            root.queue = q;
        } else {
            j = root.nextWrite();
        }
        if (!j)
            return;
        if ((j.delay ?? 0) > 0) {
            // Put it back without its delay, and come back for it.
            const q = root.queue.slice();
            q.unshift(Object.assign({}, j, { delay: 0 }));
            root.queue = q;
            wait.interval = j.delay;
            wait.restart();
            return;
        }
        root.start(j);
    }

    Timer {
        id: wait
        onTriggered: root.pump()
    }

    function start(j: var): void {
        root.job = j;
        root.seq++;
        root.outDone = false;
        root.errDone = false;
        root.exitCode = -999;

        if (j.kind === "detect") {
            worker.command = ["ddcutil", "detect"];
        } else if (j.kind === "caps") {
            worker.command = ["ddcutil", "--bus", String(j.bus), "capabilities"];
        } else if (j.kind === "fread") {
            worker.command = ["ddcutil", "--bus", String(j.bus), "getvcp", j.code, "--brief"];
        } else if (j.kind === "fwrite") {
            worker.command = ["ddcutil", "--bus", String(j.bus), "--noverify",
                              "setvcp", j.code, String(j.value)];
        } else if (j.kind === "read") {
            root.patch(j.bus, { status: j.verify !== undefined ? "verifying" : "reading" });
            worker.command = ["ddcutil", "--bus", String(j.bus), "getvcp", "10", "--brief"];
        } else {
            // The slider's value is now in flight: a newer one moved to
            // during this write becomes the next write.
            root.patch(j.bus, { status: "writing", target: j.value, want: -1 });
            worker.command = ["ddcutil", "--bus", String(j.bus), "--noverify",
                              "setvcp", "10", String(j.value)];
        }
        worker.running = false;
        worker.running = true;
        timeout.restart();
    }

    NProcess {
        id: worker
        // Failures are reported per screen, once, by finish().
        quiet: true
        stdout: StdioCollector {
            id: out
            onStreamFinished: { root.outDone = true; root.finish(); }
        }
        stderr: StdioCollector {
            id: err
            onStreamFinished: { root.errDone = true; root.finish(); }
        }
        onExited: (code) => { root.exitCode = code; root.finish(); }
    }

    Timer {
        id: timeout
        interval: root.timeoutMs
        onTriggered: {
            const j = root.job;
            if (!j)
                return;
            root.job = null;
            worker.running = false;
            if (j.kind === "detect") {
                root.detecting = false;
                root.fault = "ddcutil detect did not answer within "
                           + Math.round(root.timeoutMs / 1000) + " s";
                console.warn("ddc: " + root.fault);
            } else if (j.kind === "caps" || j.kind === "fread" || j.kind === "fwrite") {
                root.patchExtra(j.bus, { loading: false, error: "ddcutil timed out" });
            } else {
                root.fail(j.bus, "ddcutil timed out talking to this screen", true);
            }
            root.kick();
        }
    }

    function fail(bus: int, msg: string, block: bool): void {
        const was = root.state[bus]?.error ?? "";
        root.patch(bus, { status: "error", error: msg, blocked: block, want: -1 });
        if (was !== msg)
            console.warn("ddc: bus " + bus + ": " + msg);
    }

    function finish(): void {
        const j = root.job;
        if (!j || !root.outDone || !root.errDone || root.exitCode === -999)
            return;
        timeout.stop();
        root.job = null;
        const code = root.exitCode;
        const stdoutText = out.text ?? "";
        const stderrText = err.text ?? "";

        if (j.kind === "detect")
            root.onDetected(code, stdoutText, stderrText);
        else if (j.kind === "caps")
            root.onCaps(j, code, stdoutText, stderrText);
        else if (j.kind === "fread")
            root.onFeatureRead(j, code, stdoutText, stderrText);
        else if (j.kind === "fwrite")
            root.onFeatureWritten(j, code, stderrText);
        else if (j.kind === "read")
            root.onRead(j, code, stdoutText, stderrText);
        else
            root.onWritten(j, code, stderrText);
        root.kick();
    }

    function onDetected(code: int, text: string, errText: string): void {
        root.detecting = false;
        root.detected = true;
        const found = root.parseDetect(text);
        root.monitors = found;
        if (found.length === 0) {
            root.fault = code !== 0 || errText.trim() !== ""
                ? root.explain(errText + "\n" + text)
                : "No monitor answered over DDC/CI.";
            if (code !== 0)
                console.warn("ddc: detect: " + root.fault);
            return;
        }
        for (const m of found) {
            if (m.ok) {
                root.enqueue({ kind: "read", bus: m.bus }, false);
            } else {
                root.patch(m.bus, { status: "error", blocked: true,
                                    error: m.reason !== "" ? m.reason
                                         : "This screen does not answer DDC/CI. "
                                           + "It may be off in the monitor's own menu." });
            }
        }
    }

    // "VCP 10 C 40 100": feature, type, current, maximum.
    function parseBrief(text: string): var {
        const m = String(text).match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
        return m ? { cur: parseInt(m[1], 10), max: parseInt(m[2], 10) } : null;
    }

    function reason(errText: string, fallback: string): string {
        if (/DDCRC_VERIFY/.test(errText))
            return "The monitor did not confirm the change (DDCRC_VERIFY)";
        if (/DDCRC_REPORTED_UNSUPPORTED|DDCRC_UNSUPPORTED|unsupported feature/i.test(errText))
            return "This monitor does not support brightness over DDC/CI";
        if (/DDCRC_RETRIES|DDCRC_DDC_DATA|DDCRC_NULL_RESPONSE/.test(errText))
            return "The monitor stopped answering (" + (errText.match(/DDCRC_\w+/) ?? [""])[0] + ")";
        const line = errText.split("\n").map(s => s.trim()).find(s => s !== "");
        return line ?? fallback;
    }

    function onRead(j: var, code: int, text: string, errText: string): void {
        const v = root.parseBrief(text);
        if (code !== 0 || v === null) {
            if (j.verify !== undefined && (j.readNo ?? 1) === 1) {
                // A monitor busy applying the change can miss one read.
                root.enqueue(Object.assign({}, j, { readNo: 2, delay: root.settleSecond }), true);
                return;
            }
            root.fail(j.bus, root.reason(errText, "Could not read brightness"), true);
            root.applyPending();
            return;
        }
        const st = root.state[j.bus] ?? {};
        root.patch(j.bus, { cur: v.cur, max: Math.max(1, v.max) });

        if (j.verify === undefined) {
            // A read after a refused write reports the real value and
            // leaves the refusal on screen.
            root.patch(j.bus, st.blocked ? { status: "error" } : { status: "ok", error: "" });
            root.applyPending();
            return;
        }
        // Moved again since: that newer value gets written and checked,
        // and checking this one any further would be checking history.
        if (st.want >= 0) {
            root.patch(j.bus, { status: "writing" });
            return;
        }
        if (Math.abs(v.cur - j.verify) <= 1) {
            root.patch(j.bus, { status: "ok", error: "" });
            return;
        }
        if ((j.readNo ?? 1) === 1) {
            root.enqueue(Object.assign({}, j, { readNo: 2, delay: root.settleSecond }), true);
            return;
        }
        if (j.tries < root.maxWrites) {
            root.enqueue({ kind: "write", bus: j.bus, value: j.verify,
                           tries: j.tries + 1, delay: 200 }, true);
            return;
        }
        root.fail(j.bus, "The monitor kept " + v.cur + " after being set to "
                       + j.verify + ". It refused the change.", true);
    }

    function onWritten(j: var, code: int, errText: string): void {
        if (code !== 0) {
            if (j.tries < root.maxWrites && (root.state[j.bus]?.want ?? -1) < 0) {
                root.enqueue(Object.assign({}, j, { tries: j.tries + 1, delay: 600 }), true);
                return;
            }
            root.fail(j.bus, root.reason(errText, "The write failed"), true);
            // What it really is now, rather than what the slider says.
            root.enqueue({ kind: "read", bus: j.bus }, true);
            return;
        }
        // Exit 0 with --noverify only means the bytes went out.
        root.enqueue({ kind: "read", bus: j.bus, verify: j.value, tries: j.tries,
                       readNo: 1, delay: root.settleFirst }, true);
    }

    // ── Contrast, colour preset, picture mode ─────────────────────────
    //
    // Beyond brightness, three MCCS features worth a click: 0x12 contrast
    // (a range), 0x14 colour preset (sRGB, 6500 K, user...) and 0xDC
    // display mode (standard, movie, game...). Which ones a monitor has,
    // and which values the two lists take, come from its own capabilities
    // string, read once when its card is opened: offering a preset the
    // monitor does not list is offering a no-op. Written with --noverify
    // and read back once; a monitor that keeps its old value says so, and
    // brightness is not affected either way.
    //
    // bus -> { loading, loaded, error, contrast: { cur, max },
    //          preset: { cur, values: [{ code, name }] }, mode: {...} }
    property var extras: ({})

    readonly property var extraCodes: ({ "12": "contrast", "14": "preset", "DC": "mode" })

    function patchExtra(bus: int, fields: var): void {
        const next = Object.assign({}, root.extras);
        next[bus] = Object.assign({ loading: false, loaded: false, error: "",
                                    contrast: null, preset: null, mode: null },
                                  next[bus] ?? {}, fields);
        root.extras = next;
    }

    function loadExtras(bus: int): void {
        const e = root.extras[bus];
        if (e && (e.loading || e.loaded))
            return;
        root.patchExtra(bus, { loading: true, error: "" });
        root.enqueue({ kind: "caps", bus: bus }, false);
    }

    // `ddcutil capabilities`, human form:
    //    Feature: 14 (Select color preset)
    //       Values:
    //          05: 6500 K
    // or, for a feature ddcutil cannot name, "Values: 05 08 0b (...)".
    function parseCaps(text: string): var {
        const out = {};
        let cur = "";
        for (const raw of String(text).split("\n")) {
            let m;
            if ((m = raw.match(/^\s*Feature:\s*([0-9A-Fa-f]{2})\b/))) {
                cur = m[1].toUpperCase();
                out[cur] = [];
                continue;
            }
            if (cur === "")
                continue;
            if ((m = raw.match(/^\s*Values:\s*((?:[0-9A-Fa-f]{2}\s*)+)/))) {
                for (const v of m[1].trim().split(/\s+/))
                    out[cur].push({ code: v.toLowerCase(), name: "0x" + v.toLowerCase() });
                continue;
            }
            if ((m = raw.match(/^\s{6,}([0-9A-Fa-f]{2}):\s*(.+)$/)))
                out[cur].push({ code: m[1].toLowerCase(), name: m[2].trim() });
        }
        return out;
    }

    // MCCS 2.2's own names, for monitors whose capabilities list only codes.
    readonly property var standardNames: ({
        "14": { "01": "sRGB", "02": "Native", "03": "4000 K", "04": "5000 K", "05": "6500 K",
                "06": "7500 K", "07": "8200 K", "08": "9300 K", "09": "10000 K", "0a": "11500 K",
                "0b": "User 1", "0c": "User 2", "0d": "User 3" },
        "DC": { "00": "Standard", "01": "Productivity", "02": "Mixed", "03": "Movie",
                "04": "User", "05": "Games", "06": "Sports", "07": "Professional",
                "08": "Standard (low power)", "09": "Low power", "0a": "Demo", "f0": "Dynamic contrast" }
    })

    function onCaps(j: var, code: int, text: string, errText: string): void {
        if (code !== 0) {
            root.patchExtra(j.bus, { loading: false, error: root.reason(errText, "Could not read its capabilities") });
            return;
        }
        const caps = root.parseCaps(text);
        const fields = { loading: false, loaded: true };
        for (const c in root.extraCodes) {
            if (caps[c] === undefined)
                continue;
            const key = root.extraCodes[c];
            const names = root.standardNames[c] ?? {};
            const values = (caps[c] ?? []).map(v => v.name.indexOf("0x") === 0 && names[v.code]
                ? { code: v.code, name: names[v.code] } : v);
            fields[key] = c === "12" ? { cur: -1, max: 100 } : { cur: "", values: values };
            root.enqueue({ kind: "fread", bus: j.bus, code: c }, false);
        }
        root.patchExtra(j.bus, fields);
    }

    function onFeatureRead(j: var, code: int, text: string, errText: string): void {
        const key = root.extraCodes[j.code];
        const e = root.extras[j.bus] ?? {};
        if (code !== 0) {
            root.patchExtra(j.bus, { error: root.reason(errText, "Could not read it") });
            return;
        }
        const f = {};
        let m;
        if ((m = String(text).match(/VCP\s+\w+\s+C\s+(\d+)\s+(\d+)/)))
            f[key] = Object.assign({}, e[key], { cur: parseInt(m[1], 10), max: Math.max(1, parseInt(m[2], 10)) });
        else if ((m = String(text).match(/VCP\s+\w+\s+SNC\s+x([0-9a-fA-F]{2})/)))
            f[key] = Object.assign({}, e[key], { cur: m[1].toLowerCase() });
        else
            return;
        if (j.verify !== undefined) {
            const got = key === "contrast" ? f[key].cur : f[key].cur;
            const want = key === "contrast" ? j.verify : String(j.verify).toLowerCase();
            const same = key === "contrast" ? Math.abs(got - want) <= 1 : got === want;
            f.error = same ? "" : "The monitor kept its previous setting";
        }
        root.patchExtra(j.bus, f);
    }

    function onFeatureWritten(j: var, code: int, errText: string): void {
        if (code !== 0) {
            root.patchExtra(j.bus, { error: root.reason(errText, "The monitor refused it") });
            root.enqueue({ kind: "fread", bus: j.bus, code: j.code }, true);
            return;
        }
        root.enqueue({ kind: "fread", bus: j.bus, code: j.code, verify: j.raw,
                       delay: root.settleFirst }, true);
    }

    // contrast: 0..1 of its max. preset and mode: a code from its values.
    // A newer request for the same feature replaces one still queued.
    function setExtra(bus: int, key: string, value: var): void {
        const e = root.extras[bus];
        if (!e || !e[key])
            return;
        const code = Object.keys(root.extraCodes).find(c => root.extraCodes[c] === key);
        let raw, arg;
        if (key === "contrast") {
            raw = Math.round(Math.max(0, Math.min(1, value)) * e.contrast.max);
            arg = String(raw);
            root.patchExtra(bus, { contrast: Object.assign({}, e.contrast, { cur: raw }) });
        } else {
            if (!e[key].values.some(v => v.code === value))
                return;
            raw = value;
            arg = "x" + value;
            const f = {};
            f[key] = Object.assign({}, e[key], { cur: value });
            root.patchExtra(bus, f);
        }
        root.queue = root.queue.filter(q => !(q.kind === "fwrite" && q.bus === bus && q.code === code));
        root.enqueue({ kind: "fwrite", bus: bus, code: code, value: arg, raw: raw }, false);
    }

    // ── Asking for a value ────────────────────────────────────────────
    // percent: 0..1 of the monitor's own maximum.
    function set(bus: int, percent: real): void {
        const st = root.state[bus];
        if (!st || st.blocked || st.max < 1 || st.cur < 0)
            return;
        const value = Math.round(Math.max(0, Math.min(1, percent)) * st.max);
        root.patch(bus, { want: value });
        debounce.restart();
    }

    // Linked: the same fraction on every screen that accepts writes.
    function setAll(percent: real): void {
        for (const m of root.monitors)
            if (m.ok)
                root.set(m.bus, percent);
    }

    // The value a slider should show: what it asked for while that is
    // still on its way, otherwise what the monitor last said.
    function shown(bus: int): real {
        const st = root.state[bus];
        if (!st || st.max < 1)
            return 0;
        const v = st.want >= 0 ? st.want
                : (st.status === "writing" || st.status === "verifying") && st.target >= 0
                  ? st.target : st.cur;
        return Math.max(0, v) / st.max;
    }

    Timer {
        id: debounce
        interval: 220
        onTriggered: root.kick()
    }

    // ── Evening level ─────────────────────────────────────────────────
    //
    // Optional (Config.ddcEvening): every monitor that accepts writes goes
    // to the day level outside the night-light hours and to the evening
    // level inside them. Applied at login and at each change of period,
    // never in between, so a level you set by hand holds until the next
    // change. Waits for detection and the first reads, so it never writes
    // to a monitor it has not read.
    readonly property bool evening: NightLight.inSchedule
    property real pendingLevel: -1

    onEveningChanged: root.followSchedule()

    // A shell reload (any QML edit, an update) is not a new period: the
    // level is applied at most once per period per login session. The
    // marker lives in $XDG_RUNTIME_DIR, which logout empties.
    readonly property string periodMarker:
        (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/nothing-ddc-period"

    NProcess {
        id: periodCheck
        quiet: true
        property string period: ""
        command: ["sh", "-c",
            '[ "$(cat "$1" 2>/dev/null)" = "$2" ] && echo same || { printf %s "$2" > "$1"; echo apply; }',
            "ddc-period", root.periodMarker, periodCheck.period]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "apply")
                    root.applyPeriod();
            }
        }
    }

    // Login, a period change, or the settings moving: only a new period
    // (or new levels) writes; a reload of the shell does not.
    function followSchedule(): void {
        if (!Config.ddcEvening)
            return;
        periodCheck.period = (root.evening ? "evening:" : "day:")
            + Config.ddcDayLevel + ":" + Config.ddcEveningLevel;
        periodCheck.running = false;
        periodCheck.running = true;
    }

    function applyPeriod(): void {
        root.pendingLevel = (root.evening ? Config.ddcEveningLevel : Config.ddcDayLevel) / 100;
        root.wantDetect = true;
        root.ensure();
        root.applyPending();
    }

    function applyPending(): void {
        if (root.pendingLevel < 0 || !root.detected)
            return;
        const ok = root.monitors.filter(m => m.ok);
        // Every screen read (or refused) first.
        if (ok.some(m => (root.state[m.bus]?.cur ?? -1) < 0 && !(root.state[m.bus]?.blocked ?? false)))
            return;
        const level = root.pendingLevel;
        root.pendingLevel = -1;
        root.setAll(level);
    }

    Component.onCompleted: {
        probe.running = true;
        root.followSchedule();
    }
}
