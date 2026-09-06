pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Drives hypridle, started by hypr/hyprland/execs.lua. systemd is not
// used: stopping a unit would do nothing, there is none.
//
// It also owns the timings. hypridle has no runtime interface: it reads
// one config file when it starts and never looks at it again, so setting
// a delay means writing the file out and restarting the daemon. The file
// is generated whole rather than patched, because those four listeners
// are its entire content.
Singleton {
    id: root

    // Shipped defaults, and what execs.lua falls back to for a session
    // where the shell has not written the generated one yet.
    readonly property string bundled:
        Quickshell.shellPath("../../hypr/hypridle.conf")
    readonly property string generated:
        (Quickshell.env("HOME") ?? "") + "/.config/nothing/hypridle.conf"

    property bool written: false
    readonly property string config: root.written ? root.generated : root.bundled

    property bool inhibited: false      // true = sleep is disabled

    // ── The timeline ──────────────────────────────────────────────────
    // Absolute, because the daemon is restarted from here rather than
    // from the session and does not inherit NOTHING_ROOT.
    readonly property string lockCmd: Quickshell.shellPath("../../scripts/lock.sh")

    function listener(timeout: int, on: string, off: string): string {
        // 0 is never, for every one of them: the listener is simply not
        // written, which is how hypridle spells "do not".
        if (timeout <= 0)
            return "";
        let out = "listener {\n    timeout = " + timeout
            + "\n    on-timeout = " + on + "\n";
        if (off !== "")
            out += "    on-resume = " + off + "\n";
        return out + "}\n\n";
    }

    readonly property string text: {
        let s = "# Written by the Nothing shell: Settings, Interface, Idle.\n"
              + "# Edit it if you like, but the next change made there\n"
              + "# replaces the whole file.\n\n"
              + "general {\n"
              + "    lock_cmd = " + root.lockCmd + "\n"
              + "    before_sleep_cmd = loginctl lock-session\n"
              // Wait until the locker is really up before suspending, or
              // the screen comes back unlocked for a moment.
              + "    inhibit_sleep = 3\n"
              + "}\n\n";
        s += root.listener(Config.idleDim, "brightnessctl -s set 10%",
                           "brightnessctl -r");
        s += root.listener(Config.idleLock, "loginctl lock-session", "");
        s += root.listener(Config.idleOff,
                           "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'",
                           "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'");
        s += root.listener(Config.idleSuspend,
                           "systemctl suspend || loginctl suspend", "");
        return s;
    }

    // False until the file has been read once. Writing before that would
    // compare against nothing and restart the daemon on every launch.
    property bool armed: false

    function sync(): void {
        if (!root.armed || !Config.ready)
            return;
        if (file.text() === root.text)
            return;
        file.setText(root.text);
    }

    // One restart per burst: walking a picker across four values would
    // otherwise kill and relaunch the daemon four times.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.sync()
    }

    onTextChanged: settle.restart()

    FileView {
        id: file
        path: root.generated
        // Absent until the first write, which is not a fault.
        printErrors: false
        onLoaded: { root.armed = true; root.written = true; root.sync(); }
        onLoadFailed: { root.armed = true; root.sync(); }
        onSaved: {
            root.written = true;
            root.reload();
        }
    }

    // pkill -x matches the process name exactly and never the command
    // line, so it cannot also match the shell running the command.
    NProcess { id: restarter }

    function reload(): void {
        // Sleep is off on purpose. Rewriting the timings must not bring
        // the daemon back from under a game.
        if (root.inhibited)
            return;
        // No lock. flock was tried here first and is worse than nothing:
        // it returns 1 without a word when it cannot take the file, and
        // under `exec flock ... sh -c`, that failure means the restart
        // quietly does nothing at all. Self-correcting instead.
        //
        // Kill, wait until it is really gone, start one, then keep a
        // single daemon. Two restarts overlapping used to leave two
        // hypridle running, and two of them fire every timeout twice.
        // Both were started from the same config, so keeping either one
        // is correct.
        restarter.command = ["sh", "-c",
            'pkill -x hypridle 2>/dev/null; '
            + 'i=0; while pgrep -x hypridle >/dev/null && [ $i -lt 30 ]; do '
            + 'sleep 0.1; i=$((i+1)); done; '
            + 'setsid -f hypridle -c "$0" >/dev/null 2>&1; '
            + 'sleep 0.6; '
            + 'pgrep -x hypridle | head -n -1 | xargs -r kill 2>/dev/null; '
            + 'exit 0',
            root.config];
        restarter.running = false;
        restarter.running = true;
    }

    Connections {
        target: Config
        function onReadyChanged(): void { root.sync(); }
    }

    // ── Inhibiting ────────────────────────────────────────────────────
    NProcess { id: runner }

    NProcess {
        id: status
        stdout: StdioCollector {
            onStreamFinished: root.inhibited = text.trim() === ""
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            status.command = ["sh", "-c", "pgrep -x hypridle || true"];
            status.running = true;
        }
    }

    function apply(inhibit: bool): void {
        root.inhibited = inhibit;
        runner.command = ["sh", "-c", inhibit
            ? "pkill -x hypridle 2>/dev/null || true"
            // Positional, and quoted: the config path is interpolated by
            // nobody, so a space in it cannot split the command.
            : 'pgrep -x hypridle >/dev/null || hypridle -c "$1" &',
            "idle", root.config];
        runner.running = true;
    }

    function toggle(): void { root.apply(!root.inhibited); }
}
