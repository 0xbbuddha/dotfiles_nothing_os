pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Drives scripts/record.sh. State comes from pgrep, not an internal flag:
// otherwise clicking again would start instead of stop.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/record.sh")

    property bool recording: false
    property bool picking: false
    property int elapsed: 0

    // What the next recording captures. Set from the options panel, read
    // at start time. mode is "screen" or "region".
    property string mode: "screen"
    property bool wantSound: true
    property bool wantMic: false

    property string pendingAudio: ""
    property string pendingGeo: ""

    // none / sys / mic / both, the single token record.sh reads.
    function audioSpec(): string {
        if (root.wantSound && root.wantMic) return "both";
        if (root.wantSound) return "sys";
        if (root.wantMic)   return "mic";
        return "none";
    }

    signal finished(string message)

    NProcess {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out !== "")
                    root.finished(out);
                root.poll();
            }
        }
    }

    NProcess {
        id: probe
        // Exit 1 is the answer "nothing is recording", not a fault.
        quiet: true
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: (code) => {
            const on = code === 0;
            if (on && !root.recording)
                root.elapsed = 0;
            root.recording = on;
        }
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: root.poll()
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed++
    }

    Timer {
        id: pollSoon
        interval: 350
        onTriggered: root.poll()
    }

    // Let the picker vanish before wf-recorder starts filming.
    Timer {
        id: regionWait
        interval: 250
        onTriggered: {
            root.run(["start", "region", root.pendingAudio, root.pendingGeo]);
            root.recording = true;
            root.elapsed = 0;
            pollSoon.restart();
        }
    }

    function poll(): void {
        probe.running = true;
    }

    function run(args: var): void {
        runner.running = false;
        runner.command = ["sh", root.script].concat(args);
        runner.running = true;
    }

    // mode and audio are optional: omitted, they fall back to the stored
    // options the panel sets. audio is a spec token (none/sys/mic/both);
    // a plain bool is accepted too, for the older explicit callers.
    function resolveAudio(audio): string {
        if (audio === undefined || audio === null)
            return root.audioSpec();
        if (audio === true)  return "sys";
        if (audio === false) return "none";
        return audio;
    }

    function start(mode, audio): void {
        if (root.recording) {
            root.stop();
            return;
        }
        const m = (mode === undefined || mode === null || mode === "")
            ? root.mode : mode;
        const a = root.resolveAudio(audio);
        if (m === "region") {
            root.pendingAudio = a;
            root.pendingGeo = "";
            GlobalState.closeAll();
            GlobalState.controlCenterOpen = false;
            root.picking = true;
            return;
        }
        root.run(["start", "screen", a]);
        root.recording = true;
        root.elapsed = 0;
        pollSoon.restart();
    }

    function confirmRegion(geo: string): void {
        root.picking = false;
        if (geo === "")
            return;
        root.pendingGeo = geo;
        regionWait.restart();
    }

    function cancelPick(): void {
        regionWait.stop();
        root.picking = false;
        root.pendingGeo = "";
    }

    function stop(): void {
        regionWait.stop();
        root.picking = false;
        root.pendingGeo = "";
        if (runner.running)
            runner.running = false;
        root.run(["stop"]);
        root.recording = false;
        pollSoon.restart();
    }

    function toggle(mode, audio): void {
        if (root.picking) {
            root.cancelPick();
            return;
        }
        if (root.recording)
            root.stop();
        else
            root.start(mode, audio);
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c",
            'd="$(xdg-user-dir VIDEOS 2>/dev/null)"; [ -n "$d" ] || d="$HOME/Videos"; mkdir -p "$d/Captures"; xdg-open "$d/Captures"']);
    }

    function timecode(): string {
        const m = Math.floor(root.elapsed / 60);
        const s = root.elapsed % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }

    Component.onCompleted: root.poll()
}
