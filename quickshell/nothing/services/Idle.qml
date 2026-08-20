pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Drives hypridle, started by hypr/hyprland/execs.lua with the repo
// config. systemd is not used: stopping a unit would do nothing, there
// is none.
Singleton {
    id: root

    readonly property string config:
        Quickshell.shellPath("../../hypr/hypridle.conf")

    property bool inhibited: false      // true = sleep is disabled

    Process { id: runner }

    Process {
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
            : `pgrep -x hypridle >/dev/null || hypridle -c ${root.config} &`];
        runner.running = true;
    }

    function toggle(): void { root.apply(!root.inhibited); }
}
