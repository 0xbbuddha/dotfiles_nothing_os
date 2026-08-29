pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Images found in the rice and the usual folders, for the wallpaper grid.
Singleton {
    id: root

    property var files: []

    function refresh(): void {
        probe.running = true;
    }

    NProcess {
        id: probe
        running: true
        command: ["sh", "-c", `
            home="$HOME"
            for d in \
                ${JSON.stringify(Quickshell.shellPath("../../hypr"))} \
                ${JSON.stringify(Quickshell.shellPath("assets"))} \
                "$home/Documents" "$home/Pictures" "$home/Images" \
                "$home/Pictures/Wallpapers" "$home/Images/Wallpapers"; do
                [ -d "$d" ] || continue
                find "$d" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' \
                    -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null
            done | awk '!seen[$0]++' | head -48
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.trim().split("\n").filter(l => l.length > 0);
            }
        }
    }
}
