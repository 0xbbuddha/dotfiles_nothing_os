pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// Essential Space vault. Files live under ~/.local/share/nothing/essentials;
// this singleton is only the list and the commands.
Singleton {
    id: root

    property var items: []
    property int stamp: 0
    property bool busy: false
    property string status: ""
    property bool catchRecord: false
    property bool catchSong: false
    property bool catchShot: false
    property bool catchVoice: false
    property string catchShotKind: "snip"
    property bool reopen: false
    property bool hasGeminiKey: false

    readonly property string script: Quickshell.shellPath("../../scripts/essential.py")
    readonly property string dataHome: {
        const x = Quickshell.env("XDG_DATA_HOME") ?? "";
        return x.length > 0 ? x : `${Quickshell.env("HOME")}/.local/share`;
    }
    readonly property string dir: `${root.dataHome}/nothing/essentials`
    readonly property bool empty: root.items.length === 0

    function envBackend(): var {
        return ["env", `NOTHING_MIND_BACKEND=${Config.mindBackend}`];
    }

    function run(args: var): void {
        root.busy = true;
        worker.running = false;
        worker.command = root.envBackend().concat(["python3", root.script]).concat(args);
        worker.running = true;
    }

    function refresh(): void {
        lister.running = false;
        lister.command = ["python3", root.script, "list"];
        lister.running = true;
    }

    function addNote(text: string): void {
        captureWait.stop();
        root.reopen = false;
        const t = text.trim();
        if (t === "")
            return;
        if (t.startsWith("=")) {
            calc.expr = t.slice(1).trim();
            calc.running = false;
            calc.command = ["qalc", "-t", calc.expr];
            calc.running = true;
            return;
        }
        root.run(["add", "note", t]);
    }

    function addClip(): void {
        captureWait.stop();
        root.reopen = false;
        root.run(["clip"]);
    }
    function remove(id: string): void { root.run(["remove", id]); }
    function mind(id: string): void { root.run(["mind", id, Config.mindBackend]); }
    function wipe(): void { root.run(["wipe"]); }

    function probeKey(): void {
        keyProbe.running = false;
        keyProbe.command = ["python3", root.script, "has-key"];
        keyProbe.running = true;
    }

    function setBackend(name: string): void {
        backendWriter.running = false;
        backendWriter.command = ["python3", root.script, "set-backend", name];
        backendWriter.running = true;
    }

    function setGeminiKey(key: string): void {
        keyWriter.payload = key;
        keyWriter.running = false;
        keyWriter.stdinEnabled = true;
        keyWriter.running = true;
    }

    function snip(): void {
        root.catchShot = true;
        root.catchShotKind = "snip";
        root.reopen = true;
        GlobalState.essentialOpen = false;
        captureWait.restart();
    }

    function ocr(): void {
        root.catchShot = true;
        root.catchShotKind = "ocr";
        root.reopen = true;
        GlobalState.essentialOpen = false;
        captureWait.restart();
    }

    function keyShot(): void {
        captureWait.stop();
        root.catchShot = false;
        const mon = Hyprland.focusedMonitor?.name ?? "";
        if (mon === "")
            return;
        if (GlobalState.essentialOpen) {
            GlobalState.essentialOpen = false;
            keyWait.mon = mon;
            keyWait.restart();
            return;
        }
        root.grimKey(mon);
    }

    function grimKey(mon: string): void {
        keyGrim.mon = mon;
        keyGrim.running = false;
        keyGrim.command = ["sh", "-c",
            "mkdir -p /tmp/nothing-snip && grim -o \"$1\" /tmp/nothing-snip/key.png && printf '%s\\n' /tmp/nothing-snip/key.png > /tmp/nothing-snip/last",
            "grim", mon];
        keyGrim.running = true;
    }

    function finishFly(): void {
        GlobalState.essentialFlyPath = "";
        GlobalState.essentialPulse = false;
        root.startPeek(GlobalState.essentialFlyScreen);
    }

    function startPeek(screen: string): void {
        if (GlobalState.essentialOpen) {
            GlobalState.essentialCatching = false;
            return;
        }
        if ((screen ?? "") !== "")
            GlobalState.essentialFlyScreen = screen;
        GlobalState.essentialCatching = true;
        peekMin.restart();
        peekMax.restart();
    }

    function endPeek(): void {
        peekMin.stop();
        peekMax.stop();
        GlobalState.essentialCatching = false;
        if (GlobalState.essentialFlyPath === "")
            GlobalState.essentialFlyScreen = "";
    }

    function patch(id: string, fields: var): void {
        if ((id ?? "") === "" || !fields)
            return;
        patcher.payload = JSON.stringify(fields);
        patcher.running = false;
        patcher.command = ["python3", root.script, "patch", id];
        patcher.stdinEnabled = true;
        patcher.running = true;
    }

    function setWhen(id: string, iso: string): void {
        root.patch(id, { when: iso, forYou: iso !== "" });
    }

    function hideFromYou(id: string): void {
        root.patch(id, { when: "", forYou: false });
    }

    function record(): void {
        captureWait.stop();
        root.catchShot = false;
        root.catchRecord = true;
        if (Recorder.recording) {
            root.reopen = true;
            Recorder.stop();
            return;
        }
        GlobalState.essentialOpen = false;
        Recorder.start("screen", false);
    }

    function song(): void {
        if (!Songrec.available)
            return;
        root.catchSong = true;
        Songrec.clear();
        Songrec.toggle();
    }

    function ingestRecord(): void {
        root.catchRecord = false;
        root.run(["ingest-record"]);
    }

    function startVoice(): void {
        if (Voice.recording)
            return;
        root.catchVoice = true;
        GlobalState.essentialPulse = true;
        Voice.start();
    }

    function stopVoice(): void {
        if (!Voice.recording)
            return;
        Voice.stop();
    }

    function ingestVoice(): void {
        root.catchVoice = false;
        GlobalState.essentialPulse = false;
        root.run(["ingest-voice"]);
        const mon = Hyprland.focusedMonitor?.name ?? "";
        root.startPeek(mon);
    }

    function ingestSong(): void {
        root.catchSong = false;
        if (!Songrec.hasResult)
            return;
        root.run(["ingest-song", Songrec.title, Songrec.artist]);
    }

    // The value is handed over as $1, never pasted into the script text.
    // JSON.stringify looks like a shell escape and is not one: it quotes
    // quotes and backslashes but leaves $ and ` live inside double quotes,
    // so a note reading $(...) ran as a command instead of being copied.
    // These strings come from speech to text and from OCR, so they are not
    // ours to trust.
    function copyItem(it: var): void {
        if (!it)
            return;
        // A voice item carries its transcript; the recording itself is not
        // what you want on the clipboard, so text wins over path here.
        const wantsFile = it.kind !== "voice" && it.path && it.path.length > 0;
        if (wantsFile) {
            Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"',
                                     "copy-item", it.path]);
            return;
        }
        if (it.text)
            Quickshell.execDetached(["sh", "-c", `printf '%s' "$1" | wl-copy`,
                                     "copy-item", it.text]);
    }

    function openItem(it: var): void {
        if (it?.path)
            Quickshell.execDetached(["xdg-open", it.path]);
        else if (it?.kind === "song")
            Songrec.openTrack();
    }

    NProcess {
        id: keyProbe
        stdout: StdioCollector {
            onStreamFinished: root.hasGeminiKey = text.trim() === "yes"
        }
    }

    NProcess {
        id: backendWriter
    }

    NProcess {
        id: keyWriter
        property string payload: ""
        command: ["python3", root.script, "set-key"]
        onRunningChanged: {
            if (running) {
                write(payload);
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.probeKey()
        }
    }

    NProcess {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.items = Array.isArray(data) ? data : [];
                } catch (e) {
                    root.items = [];
                }
                root.stamp++;
            }
        }
    }

    NProcess {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.status = text.trim();
                root.refresh();
                if (root.reopen && (root.status.startsWith("Saved")
                        || root.status === "Mind")) {
                    root.reopen = false;
                    GlobalState.essentialOpen = true;
                } else {
                    root.reopen = false;
                }
            }
        }
        onExited: (code) => {
            if (code !== 0)
                root.busy = false;
        }
    }

    NProcess {
        id: patcher
        property string payload: ""
        onRunningChanged: {
            if (running) {
                write(payload);
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    NProcess {
        id: calc
        property string expr: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                const line = r !== ""
                    ? `${calc.expr} = ${r}`
                    : calc.expr;
                root.run(["add", "calc", line]);
            }
        }
    }

    Timer {
        id: peekMin
        interval: 4800
        onTriggered: {
            if (!root.busy)
                root.endPeek();
        }
    }

    Timer {
        id: peekMax
        interval: 14000
        onTriggered: root.endPeek()
    }

    onBusyChanged: {
        if (!root.busy && GlobalState.essentialCatching && !peekMin.running)
            root.endPeek();
    }

    Timer {
        id: captureWait
        interval: 380
        onTriggered: Shot.capture("region", "save")
    }

    Timer {
        id: keyWait
        property string mon: ""
        interval: 380
        onTriggered: root.grimKey(keyWait.mon)
    }

    NProcess {
        id: keyGrim
        property string mon: ""
        onExited: (code) => {
            if (code !== 0)
                return;
            GlobalState.essentialFlyPath = "";
            flyKick.restart();
        }
    }

    Timer {
        id: flyKick
        interval: 20
        onTriggered: {
            GlobalState.essentialFlyScreen = keyGrim.mon;
            GlobalState.essentialFlyPath = "/tmp/nothing-snip/key.png";
            GlobalState.essentialPulse = true;
            root.run(["ingest-last", "snip"]);
        }
    }

    FileView {
        path: `${root.dir}/index.json`
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.refresh()
    }

    Connections {
        target: Shot
        function onFinished(message): void {
            if (!root.catchShot)
                return;
            const kind = root.catchShotKind;
            root.catchShot = false;
            if ((message ?? "").indexOf("Cancelled") === 0
                    || (message ?? "").indexOf("No text") === 0) {
                root.reopen = false;
                return;
            }
            root.run(["ingest-last", kind]);
        }
        function onCancelled(): void {
            if (!root.catchShot)
                return;
            root.catchShot = false;
            root.reopen = false;
        }
    }

    Connections {
        target: Recorder
        function onFinished(message): void {
            if (root.catchRecord)
                root.ingestRecord();
        }
    }

    Connections {
        target: Voice
        function onFinished(message): void {
            GlobalState.essentialPulse = false;
            if (!root.catchVoice)
                return;
            if (message !== "ok") {
                root.catchVoice = false;
                return;
            }
            root.ingestVoice();
        }
    }

    Connections {
        target: Songrec
        function onHasResultChanged(): void {
            if (root.catchSong && Songrec.hasResult)
                root.ingestSong();
        }
        function onErrorChanged(): void {
            if (root.catchSong && Songrec.error !== "")
                root.catchSong = false;
        }
        function onListeningChanged(): void {
            if (!Songrec.listening && root.catchSong && !Songrec.hasResult
                    && Songrec.error !== "")
                root.catchSong = false;
        }
    }

    Component.onCompleted: {
        root.refresh();
        root.probeKey();
    }
}
