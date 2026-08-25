pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import ".."

// State behind the lock screen: the typed secret, the PAM exchange, and
// the action to run once it succeeds.
//
// Deliberately separate from the surfaces. There is one surface per
// monitor and they must all show the same attempt, the same failure and
// the same armed action.
Singleton {
    id: root

    // Driven by modules/LockScreen.qml through WlSessionLock.
    property bool locked: false

    property string secret: ""
    property bool busy: false
    property bool failed: false
    property string notice: ""

    // Armed from the lock screen and only carried out after PAM says yes,
    // so a passer-by cannot restart the machine.
    property string action: ""      // "" | logout | reboot | poweroff

    // Bumped on every failure so the surfaces can shake in unison.
    property int shake: 0

    signal granted(string action)

    function arm(name: string): void {
        root.action = (root.action === name) ? "" : name;
    }

    function type(chars: string): void {
        if (root.busy)
            return;
        root.failed = false;
        root.secret += chars;
    }

    function backspace(): void {
        if (root.busy || root.secret === "")
            return;
        root.failed = false;
        root.secret = root.secret.slice(0, -1);
    }

    function clear(): void {
        root.secret = "";
        root.failed = false;
    }

    function submit(): void {
        if (root.busy || root.secret === "")
            return;
        root.busy = true;
        root.notice = "";
        pam.start();
    }

    function reset(): void {
        root.secret = "";
        root.busy = false;
        root.failed = false;
        root.action = "";
        root.notice = "";
    }

    // A half-typed secret must not sit in memory while the screen is
    // untouched, and it must not surprise you on your return either.
    Timer {
        interval: 30000
        running: root.locked && root.secret !== "" && !root.busy
        onTriggered: root.clear()
    }

    PamContext {
        id: pam

        // pam_unix asks for the password; nothing else needs answering.
        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.secret);
        }

        onCompleted: (result) => {
            root.busy = false;
            if (result === PamResult.Success) {
                const act = root.action;
                root.secret = "";
                root.failed = false;
                root.granted(act);
                return;
            }
            root.secret = "";
            root.failed = true;
            root.shake++;
            root.notice = result === PamResult.MaxTries
                ? "Too many attempts" : "Wrong password";
        }

        onError: (error) => {
            root.busy = false;
            root.secret = "";
            root.failed = true;
            root.shake++;
            // Never leave the screen unlocked because PAM misbehaved.
            root.notice = "Authentication unavailable";
        }
    }
}
