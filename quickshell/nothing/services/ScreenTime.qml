pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// How long this session has been up.
//
// "Screen time" here is the graphical session, taken from logind's own
// timestamp rather than counted by the shell: a shell that counted would
// reset its tally every time it reloaded, which happens a lot, and a
// figure you cannot trust is worse than none.
//
// Suspend is included, as logind reports wall-clock since login. That is
// the honest reading of "since you sat down", and pretending otherwise
// would mean tracking idle across sleeps for no real gain.
Singleton {
    id: root

    // Seconds since the session began. Zero until logind answers.
    property real seconds: 0

    readonly property real limit: Math.max(600, Config.screenTimeLimit * 60)
    readonly property bool over: root.seconds > root.limit
    readonly property real fraction:
        root.limit > 0 ? Math.min(1, root.seconds / root.limit) : 0

    function refresh(): void {
        probe.running = false;
        probe.running = true;
    }

    NProcess {
        id: probe
        running: true
        // loginctl prints a monotonic microsecond stamp; comparing it to
        // /proc/uptime avoids parsing a localised date, which would break
        // the moment the machine is not in English.
        command: ["sh", "-c",
            'ts=$(loginctl show-session "$(loginctl --no-legend list-sessions ' +
            '| awk "\\$1 ~ /^[0-9]+$/ && \\$3 == \\"$USER\\" { print \\$1; exit }")" ' +
            '-p TimestampMonotonic --value 2>/dev/null); ' +
            '[ -n "$ts" ] || exit 0; ' +
            'up=$(cut -d" " -f1 /proc/uptime); ' +
            'awk -v t="$ts" -v u="$up" \'BEGIN { print u - t / 1000000 }\'',
            "screentime"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim());
                if (isFinite(v) && v >= 0)
                    root.seconds = v;
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.refresh()
    }
}
