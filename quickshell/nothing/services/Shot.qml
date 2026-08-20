pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Screenshots and OCR. All shell logic lives in
// scripts/screenshot.sh: escaping it from QML was unmanageable.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("../../scripts/screenshot.sh")
    readonly property string grabScript: Quickshell.shellPath("../../scripts/grab-outputs.py")
    readonly property string detectScript: Quickshell.shellPath("../../scripts/find-regions.py")
    readonly property string snipDir: "/tmp/nothing-snip"
    property string status: ""
    property bool busy: false
    property bool picking: false
    property bool grabPending: false
    property string pendingAction: "copy"

    signal finished(string message)

    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.status = text.trim();
                if (root.status !== "") root.finished(root.status);
            }
        }
    }

    Process {
        id: pregrab
        onExited: {
            if (!root.grabPending)
                return;
            root.grabPending = false;
            root.picking = true;
        }
    }

    // mode: region | window | screen | geo - action: copy | save | edit | ocr
    function capture(mode: string, action: string): void {
        if (mode === "region") {
            if (root.picking || root.grabPending)
                return;
            root.pendingAction = action;
            GlobalState.screenshotOpen = false;
            // Grim while the launcher / game bar stay up, then the picker
            // covers them. Closing those panels first is what kicked the
            // user out and left them out of the shot.
            root.grabPending = true;
            pregrab.running = false;
            pregrab.command = ["python3", root.grabScript];
            pregrab.running = true;
            return;
        }
        root.busy = true;
        runner.command = ["sh", root.script, mode, action];
        runner.running = true;
    }

    function confirmRegion(output: string, localGeo: string): void {
        root.picking = false;
        if (output === "" || localGeo === "")
            return;
        root.busy = true;
        runner.command = ["sh", root.script, "freeze", root.pendingAction, localGeo, output];
        runner.running = true;
    }

    function cancelPick(): void {
        root.grabPending = false;
        pregrab.running = false;
        root.picking = false;
    }
}
