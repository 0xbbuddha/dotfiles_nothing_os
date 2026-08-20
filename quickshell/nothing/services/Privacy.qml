pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Privacy indicators: mic, camera, screen share.
// Mic and share are inferred from active Pipewire links; the camera is
// read from /dev/video*, which Pipewire does not always expose.
Singleton {
    id: root

    // A stream that READS a source is a recording in progress.
    readonly property var micStreams: (Pipewire.linkGroups?.values ?? [])
        .filter(g => {
            const src = g.source;
            return src && !src.isStream && !src.isSink
                && g.target && g.target.isStream;
        })
        .map(g => g.target)
        .filter(n => n !== null)

    // Screen captures go through nodes named by the portal.
    readonly property var screenStreams: (Pipewire.nodes?.values ?? [])
        .filter(n => {
            const p = n.properties ?? ({});
            const media = String(p["media.class"] ?? "");
            const app = String(p["application.name"] ?? "").toLowerCase();
            return media.includes("Video/Source")
                || app.includes("xdg-desktop-portal")
                || app.includes("screencast");
        })

    PwObjectTracker { objects: root.micStreams }

    readonly property bool micActive: micStreams.length > 0
    readonly property bool screenActive: screenStreams.length > 0

    property bool cameraActive: false

    readonly property bool any: micActive || screenActive || cameraActive

    // Names of the apps involved, for the tooltip.
    function users(): string {
        const names = [];
        for (const n of root.micStreams) {
            const a = n.properties?.["application.name"];
            if (a && !names.includes(a)) names.push(a);
        }
        for (const n of root.screenStreams) {
            const a = n.properties?.["application.name"];
            if (a && !names.includes(a)) names.push(a);
        }
        return names.join(", ");
    }

    // Camera: look at who holds a /dev/video open.
    Process {
        id: cam
        stdout: StdioCollector {
            onStreamFinished: root.cameraActive = text.trim() !== ""
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cam.command = ["sh", "-c",
                "for d in /dev/video*; do [ -e \"$d\" ] || continue; "
                + "fuser \"$d\" 2>/dev/null && echo used && break; done"];
            cam.running = true;
        }
    }
}
