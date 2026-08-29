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

    readonly property string saveDir: `${Quickshell.env("HOME")}/Videos/Captures`

    property bool recording: false
    property bool picking: false
    property int elapsed: 0
    property bool pendingSound: false
    property string pendingGeo: ""

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
            root.run(["start", "region",
                      root.pendingSound ? "sound" : "",
                      root.pendingGeo]);
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

    function start(mode: string, sound: bool): void {
        if (root.recording) {
            root.stop();
            return;
        }
        if (mode === "region") {
            root.pendingSound = sound;
            root.pendingGeo = "";
            GlobalState.closeAll();
            GlobalState.controlCenterOpen = false;
            root.picking = true;
            return;
        }
        root.run(["start", mode, sound ? "sound" : ""]);
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

    function toggle(mode: string, sound: bool): void {
        if (root.picking) {
            root.cancelPick();
            return;
        }
        if (root.recording)
            root.stop();
        else
            root.start(mode, sound);
    }

    function openFolder(): void {
        Quickshell.execDetached(["xdg-open", root.saveDir]);
    }

    function timecode(): string {
        const m = Math.floor(root.elapsed / 60);
        const s = root.elapsed % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }

    Component.onCompleted: root.poll()
}
