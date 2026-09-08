pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The Nothing theme for Spotify, and whether it is on.
//
// Everything real happens in scripts/apply-spicetify.sh; this reads its
// --status output and drives it. Keeping the logic in the script rather
// than here is deliberate: the same theme has to be installable from a
// terminal on a machine with no shell running, and two implementations of
// "is it applied" would disagree the first week.
//
// Nothing is polled. Spotify's install only changes when a package is
// upgraded or the user acts, so the state is read when the settings page
// opens and after every action.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/apply-spicetify.sh")

    // False until the first status read lands. Every label below would
    // otherwise spend a frame claiming Spotify is not installed.
    property bool known: false

    property bool hasSpotify: false
    property bool hasSpicetify: false
    property bool writable: false
    property bool applied: false

    // What the patched client currently carries, against what the shell
    // would write now. The gap between the two is the whole reason this
    // service reports anything beyond a boolean: changing the accent in
    // settings leaves a themed Spotify sitting on the old one.
    property string accent: ""
    property string scheme: ""
    property string wantAccent: ""
    property string wantScheme: ""
    property string dir: ""

    property bool busy: false
    property string error: ""

    readonly property bool stale: root.applied
        && (root.accent !== root.wantAccent || root.scheme !== root.wantScheme)

    // One word for the panel to switch on, so the page holds no logic of
    // its own about what is missing.
    readonly property string state: {
        if (!root.known)        return "unknown";
        if (!root.hasSpotify)   return "noSpotify";
        if (!root.hasSpicetify) return "noSpicetify";
        if (root.applied)       return root.stale ? "stale" : "on";
        return root.writable ? "off" : "locked";
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
                root.hasSpotify   = kv.spotify === "1";
                root.hasSpicetify = kv.spicetify === "1";
                root.writable     = kv.writable === "1";
                root.applied      = kv.applied === "1";
                root.accent       = kv.accent ?? "";
                root.scheme       = kv.scheme ?? "";
                root.wantAccent   = kv.wantAccent ?? "";
                root.wantScheme   = kv.wantScheme ?? "";
                root.dir          = kv.dir ?? "";
                root.known = true;
            }
        }
    }

    // The long ones. Their output is worth keeping: when spicetify refuses
    // it says why, and "it did not work" with the reason thrown away is
    // the failure mode this whole shell was written against.
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
            root.error = code === 0 ? "" : (runner.tail || "spicetify failed");
            root.refresh();
        }
    }

    function refresh(): void { status.running = true; }

    // --fix-perms is always passed. It is a no-op once /opt/spotify is
    // writable, and the alternative is a first click that fails with an
    // explanation and a second one that works.
    function apply(): void {
        if (root.busy || !root.hasSpicetify) return;
        root.busy = true;
        root.error = "";
        runner.command = ["sh", root.script, "--fix-perms"];
        runner.running = true;
    }

    function revert(): void {
        if (root.busy || !root.hasSpicetify) return;
        root.busy = true;
        root.error = "";
        runner.command = ["sh", root.script, "--revert"];
        runner.running = true;
    }

    // spicetify comes from the AUR, which means a build, a diff to read and
    // a password. That belongs in a terminal the user is looking at, not in
    // a process this shell starts behind a spinner.
    function installSpicetify(): void {
        Quickshell.execDetached([
            Config.terminal, "-e", "sh", "-c",
            "yay -S spicetify-cli || paru -S spicetify-cli; "
            + "printf '\\nDone. Press enter. '; read -r _"
        ]);
    }
}
