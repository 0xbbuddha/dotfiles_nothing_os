pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Apps started at login, chosen in Settings > System.
//
// Stored as .desktop ids, not commands: an app is launched exactly as the
// launcher launches it (DesktopEntry.execute()), so nothing typed in a
// settings field ever reaches a shell, and an app that is uninstalled
// simply drops out with a note instead of failing at every login.
//
// Once per Hyprland session, not once per shell: the shell reloads on every
// edit of its files and on "Reload the shell", and each of those would
// otherwise open Discord again. A marker in $XDG_RUNTIME_DIR named after
// the Hyprland instance says this session already did it; the runtime dir
// is emptied at logout, so the next login starts them again.
//
// An app already running is skipped (pgrep on its executable), so one that
// is also started by custom.lua's exec-once, or that restored itself, does
// not open twice. Your own exec-once lines are not read or changed.
Singleton {
    id: root

    property var started: []       // ids launched this session
    property var skipped: []       // [{ id, why }]
    property bool ran: false

    readonly property string marker: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp";
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "nohypr";
        return dir + "/nothing-autostart-" + sig.replace(/[^A-Za-z0-9_.-]/g, "_");
    }

    function add(id: string): void {
        const list = (Config.autostartApps ?? []).slice();
        if (list.indexOf(id) >= 0)
            return;
        list.push(id);
        Config.autostartApps = list;
        Config.save();
    }

    function remove(id: string): void {
        Config.autostartApps = (Config.autostartApps ?? []).filter(x => x !== id);
        Config.save();
    }

    // The program a .desktop entry runs, for the "already running" check.
    // Flatpak and env wrappers name something else, so those are always
    // started: a duplicate is better than an app that never comes up.
    function binaryOf(entry: var): string {
        const cmd = entry?.command ?? [];
        const first = String(cmd[0] ?? "");
        const base = first.split("/").pop();
        if (base === "" || base === "env" || base === "flatpak" || base === "sh")
            return "";
        return base;
    }

    // ── Once per session ──────────────────────────────────────────────
    NProcess {
        id: claim
        // Creates the marker and answers "run" only the first time. `set -C`
        // makes the redirect fail if it exists, so two shells starting at
        // once cannot both claim it. `true`, not `:`: a failed redirect on
        // the special builtin `:` ends a POSIX sh outright.
        command: ["sh", "-c", 'set -C; { true > "$1"; } 2>/dev/null && echo run || echo done',
                  "autostart", root.marker]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "run")
                    delay.restart();
            }
        }
    }

    Timer {
        id: delay
        // Lets the session settle (portals, tray, keyring) before apps that
        // look for them start.
        interval: Math.max(0, Config.autostartDelay) * 1000
        onTriggered: root.startAll()
    }

    // Exact ids only: the launcher's fuzzy lookup could match a different
    // app to one that has since been uninstalled.
    function entryOf(id: string): var {
        return DesktopEntries.byId(id) ?? null;
    }

    property int waited: 0

    function startAll(): void {
        // The .desktop scan can still be running right after login.
        if ((DesktopEntries.applications?.values ?? []).length === 0 && root.waited < 10) {
            root.waited++;
            delay.interval = 1000;
            delay.restart();
            return;
        }
        root.ran = true;
        root.skipped = [];
        root.queue = (Config.autostartApps ?? []).slice();
        root.next();
    }

    // One at a time through a pgrep each, so the check and the launch are
    // never racing another app's.
    property var queue: []

    function next(): void {
        while (root.queue.length > 0) {
            const q = root.queue.slice();
            const id = q.shift();
            root.queue = q;
            const e = root.entryOf(id);
            if (!e) {
                root.skipped = root.skipped.concat([{ id: id, why: "not installed" }]);
                console.warn("autostart: " + id + " is not installed, skipped");
                continue;
            }
            const bin = root.binaryOf(e);
            if (bin === "") {
                root.launch(id, e);
                continue;
            }
            check.pending = id;
            check.command = ["pgrep", "-x", "--", bin.substring(0, 15)];
            check.running = true;
            return;
        }
    }

    function launch(id: string, e: var): void {
        e.execute();
        root.started = root.started.concat([id]);
    }

    NProcess {
        id: check
        // pgrep exits 1 when nothing matches: an answer, not a fault.
        quiet: true
        property string pending: ""
        onExited: (code) => {
            const id = check.pending;
            const e = root.entryOf(id);
            if (code === 0)
                root.skipped = root.skipped.concat([{ id: id, why: "already running" }]);
            else if (e)
                root.launch(id, e);
            root.next();
        }
    }

    // "Start now" in the settings page: same rules, without the marker.
    function startNow(): void {
        root.startAll();
    }

    Component.onCompleted: {
        if ((Config.autostartApps ?? []).length > 0)
            claim.running = true;
    }
}
