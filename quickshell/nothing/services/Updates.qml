pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Pending update count, via checkupdates (pacman-contrib).
// checkupdates does not write the pacman database; it is safe to run in
// a loop without special privileges.
Singleton {
    id: root

    property int count: 0
    property bool available: false
    property var packages: []

    readonly property bool advised: count >= 10
    readonly property bool urgent: count >= 40

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        id: probe
        running: true
        command: ["sh", "-c", "command -v checkupdates >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                if (root.available) check.running = true;
            }
        }
    }

    NProcess {
        id: check
        command: ["sh", "-c", "checkupdates 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.trim() !== "");
                root.count = lines.length;
                root.packages = lines.slice(0, 20);
            }
        }
    }

    // Every 30 minutes: checkupdates hits the network.
    Timer {
        interval: 30 * 60 * 1000
        running: root.available
        repeat: true
        onTriggered: check.running = true
    }

    function refresh(): void { if (root.available) check.running = true; }

    function install(): void {
        Quickshell.execDetached([
            Config.terminal, "-e", "sh", "-c",
            "sudo pacman -Syu; printf '\\nDone. Press enter. '; read -r _"
        ]);
    }
}
