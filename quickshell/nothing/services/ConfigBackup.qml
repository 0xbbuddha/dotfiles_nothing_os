pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Copies of config.json, kept next to it in ~/.config/nothing/backups.
//
// A backup is the file as it is on disk, nothing more: restoring one
// copies it back over config.json, and Config's FileView, which watches
// that file, reloads every setting on its own. Before anything is
// overwritten the current file is copied aside as
// config-<stamp>-before-restore.json, so a restore can itself be undone
// from the same list. A backup that is not a JSON object is refused
// before anything is touched.
//
// Paths travel as arguments ($1, $2...), never inside the script text.
Singleton {
    id: root

    readonly property string dir: Config.dir + "/backups"
    property var list: []          // file names, newest first
    property string status: ""
    property bool busy: false

    readonly property var nameRe: /^config-\d{8}-\d{6}(-before-restore)?\.json$/

    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    }

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    NProcess {
        id: lister
        // No folder yet is an empty list, not a fault.
        quiet: true
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f",
                  "-name", "config-*.json", "-printf", "%f\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.split("\n").map(s => s.trim())
                    .filter(s => root.nameRe.test(s)).sort().reverse();
            }
        }
    }

    function backup(): void {
        if (root.busy)
            return;
        Config.save();
        root.busy = true;
        // A pending save (80 ms debounce) reaches the disk first.
        backupLater.restart();
    }

    Timer {
        id: backupLater
        interval: 250
        onTriggered: {
            const name = "config-" + root.stamp() + ".json";
            runner.label = "settings backup";
            runner.done = "Saved as " + name;
            runner.command = ["sh", "-c",
                'mkdir -p -- "$1" && cp -- "$2" "$1/$3"',
                "config-backup", root.dir, Config.path, name];
            runner.running = true;
        }
    }

    function restore(name: string): void {
        if (root.busy || !root.nameRe.test(name))
            return;
        root.busy = true;
        const aside = "config-" + root.stamp() + "-before-restore.json";
        runner.label = "settings restore";
        runner.done = "Restored " + name + ". The previous settings are in " + aside;
        runner.command = ["sh", "-c",
            'python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d, dict) else 1)" "$1/$2" '
            + '|| { echo "not a valid settings file" >&2; exit 3; }; '
            + 'cp -- "$3" "$1/$4" && cp -- "$1/$2" "$3.restore" && mv -- "$3.restore" "$3"',
            "config-restore", root.dir, name, Config.path, aside];
        runner.running = true;
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p -- "$1" && xdg-open "$1"',
                                 "config-backup", root.dir]);
    }

    NProcess {
        id: runner
        property string done: ""
        stderr: StdioCollector {
            id: runErr
        }
        onExited: (code) => {
            root.busy = false;
            root.status = code === 0 ? runner.done
                : ("Failed: " + (runErr.text.trim().split("\n")[0] || ("exit " + code)));
            if (code !== 0)
                console.warn(runner.label + ": " + root.status);
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
