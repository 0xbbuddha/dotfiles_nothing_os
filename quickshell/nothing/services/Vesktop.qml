pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The Nothing theme for Vesktop, and whether it is on.
//
// Everything real happens in scripts/apply-vesktop-theme.sh; this reads its
// --status output and drives it, the same split as Spicetify.qml and for
// the same reason: the theme has to be installable from a terminal with no
// shell running, so the logic lives where that terminal can reach it.
//
// Simpler than Spicetify: no accent to fall out of sync with, no root
// needed to write into ~/.config, so there is no "stale" or "locked"
// state, only whether the theme is on.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/apply-vesktop-theme.sh")

    // False until the first status read lands, same reasoning as
    // Spicetify.known: otherwise the row claims Vesktop is missing for
    // one frame on every settings open.
    property bool known: false

    property bool hasVesktop: false
    property bool installed: false
    property bool enabled: false

    property bool busy: false
    property string error: ""

    readonly property string state: {
        if (!root.known)      return "unknown";
        if (!root.hasVesktop) return "noVesktop";
        return (root.installed && root.enabled) ? "on" : "off";
    }

    NProcess {
        id: status
        quiet: true
        command: ["sh", root.script, "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.hasVesktop = kv.vesktop === "1";
                root.installed  = kv.installed === "1";
                root.enabled    = kv.enabled === "1";
                root.known = true;
            }
        }
    }

    NProcess {
        id: runner
        property string tail: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.trim() !== "");
                runner.tail = lines.length > 0 ? lines[lines.length - 1] : "";
            }
        }
        onExited: (code) => {
            root.busy = false;
            root.error = code === 0 ? "" : (runner.tail || "the script failed");
            root.refresh();
        }
    }

    function refresh(): void { status.running = true; }

    function apply(): void {
        if (root.busy || !root.hasVesktop) return;
        root.busy = true;
        root.error = "";
        runner.command = ["sh", root.script];
        runner.running = true;
    }

    function revert(): void {
        if (root.busy || !root.hasVesktop) return;
        root.busy = true;
        root.error = "";
        runner.command = ["sh", root.script, "--revert"];
        runner.running = true;
    }
}
