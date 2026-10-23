pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The programs using the machine, for Settings > Processes. Sampled by
// scripts/procs.py every two seconds while that page is on screen, and
// not at all otherwise.
//
// Ending a program sends SIGTERM to every process of that name that is
// yours, which lets it save and close; "Force" sends SIGKILL. Programs run
// by another user (root, system services) are listed but cannot be ended
// from here, and the session's own (Hyprland, the shell, PipeWire...) are
// marked and refused, because ending them ends the desktop or the sound.
Singleton {
    id: root

    property bool active: false
    property string sort: "cpu"        // "cpu" | "mem"
    property var items: []
    property int cores: 1
    property real memTotal: 0
    property real memUsed: 0
    property var ended: ({})           // name -> true once SIGTERM was sent
    property string status: ""

    readonly property string script: Quickshell.shellPath("../../scripts/procs.py")

    onActiveChanged: if (root.active) sampler.restart()
    onSortChanged: if (root.active) sampler.restart()

    Timer {
        id: sampler
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (reader.running)
                return;
            reader.command = ["python3", "-I", root.script, root.sort, "15"];
            reader.running = true;
        }
    }

    NProcess {
        id: reader
        label: "processes"
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try { d = JSON.parse(text); } catch (e) { return; }
                root.items = d.items ?? [];
                root.cores = d.cores ?? 1;
                root.memTotal = d.memTotal ?? 0;
                root.memUsed = d.memUsed ?? 0;
                // A program that is gone no longer needs its Force button.
                const left = {};
                for (const n in root.ended)
                    if (root.items.some(i => i.name === n))
                        left[n] = true;
                root.ended = left;
            }
        }
    }

    function gb(bytes: real): string {
        return bytes >= 1e9 ? (bytes / 1e9).toFixed(1) + " GB" : Math.round(bytes / 1e6) + " MB";
    }

    function end(item: var, force: bool): void {
        if (!item || !item.mine || item.protected || item.pids.length === 0)
            return;
        // Numbers only: the pids come from /proc, never from text.
        const pids = item.pids.filter(p => Number.isInteger(p) && p > 1).map(String);
        killer.what = item.name;
        killer.command = ["kill", force ? "-KILL" : "-TERM", "--"].concat(pids);
        killer.running = true;
        if (!force) {
            const e = Object.assign({}, root.ended);
            e[item.name] = true;
            root.ended = e;
        }
    }

    NProcess {
        id: killer
        quiet: true
        property string what: ""
        stderr: StdioCollector { id: killErr }
        onExited: (code) => {
            root.status = code === 0 ? "Asked " + killer.what + " to close"
                : killer.what + ": " + (killErr.text.trim().split("\n")[0] || "could not end it");
            sampler.restart();
        }
    }
}
