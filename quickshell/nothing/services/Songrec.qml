pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Music recognition, Shazam-style, via songrec.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/songrec.sh")

    property bool listening: false
    property string title: ""
    property string artist: ""
    property string error: ""
    property int elapsed: 0
    readonly property int duration: 16

    readonly property bool available: probe.found
    readonly property bool hasResult: title !== ""

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v songrec >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: probe.found = text.trim() === "yes"
        }
    }

    NProcess {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                root.listening = false;
                const out = text.trim();
                if (out.includes("|")) {
                    const p = out.split("|");
                    root.title = p[0];
                    root.artist = p.slice(1).join("|");
                    root.error = "";
                } else {
                    root.title = "";
                    root.artist = "";
                    root.error = out !== "" ? out : "No match";
                }
            }
        }
    }

    Timer {
        running: root.listening
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }

    function start(): void {
        if (root.listening || !root.available) return;
        root.listening = true;
        root.elapsed = 0;
        root.title = "";
        root.artist = "";
        root.error = "";
        runner.command = ["sh", root.script, String(root.duration)];
        runner.running = true;
    }

    function stop(): void {
        runner.running = false;
        root.listening = false;
    }

    function toggle(): void {
        if (root.listening) root.stop();
        else root.start();
    }

    function clear(): void {
        root.title = "";
        root.artist = "";
        root.error = "";
    }

    // Opens the recognised track on YouTube, as ii does.
    function openTrack(): void {
        if (!root.hasResult) return;
        const q = encodeURIComponent(`${root.title} ${root.artist}`);
        lookup.command = ["sh", "-c",
            `xdg-open "https://www.youtube.com/results?search_query=${q}"`];
        lookup.running = true;
    }

    NProcess { id: lookup }
}
