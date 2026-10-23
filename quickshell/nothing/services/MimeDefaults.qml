pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Which app opens which kind of file (Settings > Dock > Default apps).
// The reading and writing of ~/.config/mimeapps.list is in
// scripts/mime-defaults.py; this only lists and asks. Read when the page
// opens, never polled.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("../../scripts/mime-defaults.py")

    // [{ key, label, current, currentName, candidates: [{ id, name }] }]
    property var categories: []
    property string error: ""
    property bool busy: false

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    NProcess {
        id: lister
        label: "default apps"
        command: ["python3", "-I", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.categories = JSON.parse(text);
                } catch (e) {
                    root.error = "Could not read the default apps";
                }
            }
        }
    }

    function set(key: string, id: string): void {
        if (root.busy)
            return;
        root.busy = true;
        root.error = "";
        setter.command = ["python3", "-I", root.script, "set", key, id];
        setter.running = true;
    }

    NProcess {
        id: setter
        label: "default apps"
        stderr: StdioCollector { id: setErr }
        onExited: (code) => {
            root.busy = false;
            if (code !== 0)
                root.error = setErr.text.trim().split("\n").pop() || "Refused";
            root.refresh();
        }
    }
}
