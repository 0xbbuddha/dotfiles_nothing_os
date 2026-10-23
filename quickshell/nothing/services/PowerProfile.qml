pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Power profiles through power-profiles-daemon (or tuned-ppd, which
// answers the same powerprofilesctl). Saver, balanced, performance: what
// the daemon does with them (CPU energy preference, platform profile)
// is its business and differs per machine, so the page names the
// profile and nothing more.
//
// Optional. Without powerprofilesctl, or with it but no daemon behind
// it, `available` stays false and the page says what is missing.
// Read when the page asks, never polled.
Singleton {
    id: root

    property bool available: false
    property bool probed: false
    property string current: ""
    property var profiles: []      // what this machine offers, in order
    property string error: ""

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    NProcess {
        id: lister
        // No daemon is an answer here, not a fault.
        quiet: true
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "* balanced:" marks the active one; settings follow
                // indented on the lines under each name.
                const found = [];
                let cur = "";
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\*?)\s*([a-z-]+):\s*$/);
                    if (!m)
                        continue;
                    found.push(m[2]);
                    if (m[1] === "*")
                        cur = m[2];
                }
                const order = ["power-saver", "balanced", "performance"];
                root.profiles = order.filter(p => found.indexOf(p) >= 0);
                root.current = cur;
                root.available = root.profiles.length > 0;
                root.probed = true;
            }
        }
    }

    function set(name: string): void {
        if (root.profiles.indexOf(name) < 0)
            return;
        root.current = name;
        root.error = "";
        setter.running = false;
        setter.command = ["powerprofilesctl", "set", name];
        setter.running = true;
    }

    function cycle(): void {
        if (root.profiles.length === 0)
            return;
        const i = root.profiles.indexOf(root.current);
        root.set(root.profiles[(i + 1) % root.profiles.length]);
    }

    NProcess {
        id: setter
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t !== "") {
                    root.error = t.split("\n")[0];
                    console.warn("power profile: " + root.error);
                }
            }
        }
        // Whatever it ended up as, including a refusal.
        onExited: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
