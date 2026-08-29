pragma Singleton

import QtQuick
import Quickshell
import ".."

// Microphone notes for the Essential Key long-press.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/voice.sh")

    property bool recording: false
    property int elapsed: 0
    property string error: ""
    property double startedAt: 0
    readonly property int cap: 90

    signal finished(string message)

    NProcess {
        id: rec
        onExited: {
            const ms = Date.now() - root.startedAt;
            root.recording = false;
            capStop.stop();
            if (ms < 450) {
                root.finished("short");
                return;
            }
            root.finished("ok");
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: {
            root.elapsed++;
            if (root.elapsed >= root.cap)
                root.stop();
        }
    }

    Timer {
        id: capStop
        interval: root.cap * 1000
        onTriggered: root.stop()
    }

    function start(): void {
        if (root.recording)
            return;
        root.error = "";
        root.elapsed = 0;
        root.startedAt = Date.now();
        rec.running = false;
        rec.command = ["sh", root.script, "record"];
        rec.running = true;
        root.recording = true;
        capStop.restart();
    }

    function stop(): void {
        capStop.stop();
        if (rec.running)
            rec.running = false;
        else
            root.recording = false;
    }

    function toggle(): void {
        if (root.recording)
            root.stop();
        else
            root.start();
    }

    function timecode(): string {
        const m = Math.floor(root.elapsed / 60);
        const s = root.elapsed % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }
}
