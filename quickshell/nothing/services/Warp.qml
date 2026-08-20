pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cloudflare WARP (1.1.1.1). Hidden until warp-cli is installed.
Singleton {
    id: root

    property bool available: false
    property bool connected: false
    property bool busy: false

    readonly property string label: {
        if (root.busy) return "…";
        if (root.connected) return "on";
        return "1.1.1.1";
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v warp-cli >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                if (root.available)
                    status.running = true;
            }
        }
    }

    Process {
        id: status
        command: ["warp-cli", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: register
        command: ["warp-cli", "registration", "new"]
        onExited: (code) => {
            if (code === 0)
                Quickshell.execDetached(["warp-cli", "connect"]);
            root.busy = false;
            poll.restart();
        }
    }

    Timer {
        id: poll
        interval: 4000
        running: root.available
        repeat: true
        onTriggered: status.running = true
    }

    function parse(text: string): void {
        const t = text;
        if (t.includes("Connected")) {
            root.connected = true;
            root.busy = false;
        } else if (t.includes("Connecting")) {
            root.busy = true;
        } else if (t.includes("Disconnected")) {
            root.connected = false;
            root.busy = false;
        }
    }

    function refresh(): void {
        probe.running = true;
    }

    function toggle(): void {
        if (!root.available)
            return;
        root.busy = true;
        if (root.connected) {
            root.connected = false;
            Quickshell.execDetached(["warp-cli", "disconnect"]);
            poll.restart();
            return;
        }
        root.connected = true;
        Quickshell.execDetached(["warp-cli", "connect"]);
        Qt.callLater(() => status.running = true);
        failCheck.restart();
    }

    // First click with no account: warp-cli connect fails, so we register.
    Timer {
        id: failCheck
        interval: 900
        onTriggered: {
            if (!root.available)
                return;
            checkReg.running = true;
        }
    }

    Process {
        id: checkReg
        command: ["warp-cli", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text;
                if (t.includes("Unable") || t.includes("Registration")
                    || t.includes("not registered") || t.includes("Missing")) {
                    register.running = true;
                    return;
                }
                root.parse(t);
            }
        }
    }
}
