pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Google Lens image search on a screen selection.
// The captured crop is uploaded to a third-party host for a public URL:
// that is the cost of the feature, and it is disclosed in use.
Singleton {
    id: root

    readonly property string script:
        Quickshell.shellPath("../../scripts/lens.sh")

    property bool busy: false
    signal finished(string message)

    NProcess {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                const out = text.trim();
                if (out !== "") root.finished(out);
            }
        }
    }

    function search(): void {
        if (root.busy) return;
        root.busy = true;
        runner.command = ["sh", root.script];
        runner.running = true;
    }
}
