pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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
    property bool secure: false

    readonly property string flagPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nothing-locked"
    readonly property string fallbackGuard: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nothing-fallback-lock.lock"

    property string secret: ""
    property bool busy: false
    property bool failed: false
    property string notice: ""

    // Armed from the lock screen, expires, and only offered for confirmation
    // after PAM says yes, so a passer-by cannot restart the machine.
    property string action: ""      // "" | logout | reboot | poweroff
    property string pendingAction: ""

    // Bumped on every failure so the surfaces can shake in unison.
    property int shake: 0

    // Fingerprint, when the machine has a reader with something enrolled.
    property bool fingerprint: false
    property string fingerNotice: ""

    signal granted(string action)

    function activate(): void {
        if (root.locked)
            return;
        root.reset();
        root.locked = true;
    }

    function compositorReleased(): void {
        if (!root.locked)
            return;
        root.locked = false;
        root.reset();
    }

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
        // One PAM conversation at a time: a pending fingerprint attempt
        // would otherwise answer the password prompt.
        root.stopFinger();
        root.busy = true;
        root.notice = "";
        secretExpiry.restart();
        if (!pam.start()) {
            root.busy = false;
            root.secret = "";
            root.failed = true;
            root.shake++;
            root.notice = "Authentication unavailable";
            root.watchFinger();
        }
    }

    function reset(): void {
        root.secret = "";
        root.busy = false;
        root.failed = false;
        root.action = "";
        root.notice = "";
        root.fingerNotice = "";
    }

    // fprintd stops listening after about thirty seconds. Rather than
    // leave the reader dead until the next keystroke, the attempt is
    // started again whenever it lapses while the screen is still locked.
    function watchFinger(): void {
        if (!root.fingerprint || !root.locked || root.busy)
            return;
        if (!fingerPam.active)
            fingerPam.start();
    }

    function stopFinger(): void {
        if (fingerPam.active)
            fingerPam.abort();
    }

    onLockedChanged: {
        if (root.locked) {
            Quickshell.execDetached(["touch", root.flagPath]);
            root.watchFinger();
        } else {
            Quickshell.execDetached(["sh", "-c", 'flock -n "$1" rm -f "$2"', "lock-flag",
                root.fallbackGuard, root.flagPath]);
            root.secure = false;
            root.stopFinger();
        }
    }

    onSecretChanged: {
        if (root.secret === "")
            secretExpiry.stop();
        else
            secretExpiry.restart();
    }

    onActionChanged: {
        if (root.action === "")
            actionExpiry.stop();
        else
            actionExpiry.restart();
    }

    NProcess {
        quiet: true
        running: true
        command: ["test", "-e", root.flagPath]
        onExited: (code) => {
            if (code === 0)
                root.activate();
        }
    }

    NProcess {
        id: lockedOut
        quiet: true
        command: ["sh", Quickshell.shellPath("../../scripts/fallback-lock/faillock-remaining.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const left = parseInt(text.trim(), 10);
                if (!isNaN(left))
                    root.notice = left > 0
                        ? "Account locked, try again in " + Math.ceil(left / 60) + " min"
                        : "Account locked";
            }
        }
    }

    Timer {
        id: actionExpiry
        interval: 30000
        onTriggered: root.action = ""
    }

    NProcess {
        running: true
        // whoami rather than $USER: the variable is set in a normal
        // session but nothing guarantees it in the shell's environment.
        command: ["sh", "-c", "fprintd-list \"$(whoami)\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fingerprint = text.indexOf("Fingerprints for user") >= 0;
                if (root.fingerprint && root.locked)
                    root.watchFinger();
            }
        }
    }

    PamContext {
        id: fingerPam
        // Relative to this file, so "pam" is services/pam next door.
        configDirectory: "pam"
        config: "fprintd.conf"

        // pam_fprintd runs a retry loop of its own: one start() can refuse
        // several fingers before the stack ever completes, and each refusal
        // arrives here rather than in onCompleted. Without this the screen
        // sits on its invitation through every failed touch, which reads as
        // a dead reader rather than a finger that was seen and rejected.
        //
        // Which message is a refusal is taken from messageIsError, never
        // from the text: PAM's wording follows the system locale, and this
        // shell speaks English throughout.
        onPamMessage: {
            if (fingerPam.messageIsError) {
                root.fingerNotice = "Finger not recognised";
                fingerClear.restart();
            }
        }

        // PAM's own text is never shown: it is translated by the system
        // locale, and this shell speaks English throughout. The states
        // worth reporting are few enough to word here.
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                root.fingerNotice = "";
                const act = root.action;
                root.secret = "";
                root.failed = false;
                root.granted(act);
                return;
            }
            // A refusal is not a lockout here: the reader simply lapsed or
            // the finger was not recognised, so listen again.
            if (result !== PamResult.Error) {
                root.fingerNotice = "Finger not recognised";
                fingerClear.restart();
            }
            fingerRetry.restart();
        }

        onError: (error) => fingerRetry.restart()
    }

    Timer {
        id: fingerRetry
        interval: 600
        onTriggered: root.watchFinger()
    }

    // The refusal fades back to the plain invitation rather than sitting
    // there accusing you.
    Timer {
        id: fingerClear
        interval: 2600
        onTriggered: root.fingerNotice = ""
    }

    // A half-typed secret must not sit in memory while the screen is
    // untouched, and it must not surprise you on your return either.
    Timer {
        id: secretExpiry
        interval: 30000
        onTriggered: {
            if (root.busy) {
                pam.abort();
                root.busy = false;
                root.notice = "Authentication timed out";
                root.watchFinger();
            }
            root.clear();
        }
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
                root.stopFinger();
                root.granted(act);
                return;
            }
            root.secret = "";
            // The reader was stopped to make way for the password; a
            // refusal must hand it back rather than leave it deaf.
            root.watchFinger();
            if (result === PamResult.Error)
                return;
            root.failed = true;
            root.shake++;
            root.notice = result === PamResult.MaxTries
                ? "Too many attempts" : "Wrong password";
            lockedOut.running = true;
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
