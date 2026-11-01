import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    property string secret: ""
    property bool busy: false
    property string notice: ""
    property bool unlocking: false

    readonly property string flagPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nothing-locked"

    function forget(): void {
        root.secret = "";
        root.busy = false;
    }

    function submit(): void {
        if (root.busy || root.secret === "")
            return;
        root.busy = true;
        root.notice = "";
        expiry.restart();
        if (!pam.start()) {
            root.forget();
            root.notice = "Authentication unavailable";
        }
    }

    onSecretChanged: {
        if (root.secret === "")
            expiry.stop();
        else
            expiry.restart();
    }

    Component.onCompleted: Quickshell.watchFiles = false

    IpcHandler {
        target: "lock"
        function activate(): string {
            return session.locked && session.secure ? "ok" : "pending";
        }
        function secure(): string {
            return session.locked && session.secure ? "true" : "false";
        }
    }

    Timer {
        id: expiry
        interval: 30000
        onTriggered: {
            if (root.busy) {
                pam.abort();
                root.notice = "Authentication timed out";
            }
            root.forget();
        }
    }

    Timer {
        id: quitSoon
        interval: 200
        onTriggered: Qt.quit()
    }

    Process {
        id: lockedOut
        command: ["sh", Quickshell.shellPath("faillock-remaining.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const left = parseInt(this.text.trim(), 10);
                if (!isNaN(left))
                    root.notice = left > 0
                        ? "Account locked, try again in " + Math.ceil(left / 60) + " min"
                        : "Account locked";
            }
        }
    }

    PamContext {
        id: pam

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.secret);
        }

        onCompleted: result => {
            const wanted = root.busy;
            root.forget();
            if (result === PamResult.Success) {
                root.unlocking = true;
                session.locked = false;
                Quickshell.execDetached(["rm", "-f", root.flagPath]);
                quitSoon.start();
                return;
            }
            if (result === PamResult.Error || !wanted)
                return;
            root.notice = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
            lockedOut.running = true;
        }

        onError: error => {
            root.forget();
            root.notice = "Authentication unavailable";
        }
    }

    WlSessionLock {
        id: session
        locked: true

        onSecureStateChanged: {
            if (session.secure)
                Quickshell.execDetached(["touch", root.flagPath]);
            else if (!root.unlocking)
                Qt.callLater(Qt.quit);
        }

        onLockStateChanged: {
            if (!session.locked && !root.unlocking)
                Qt.callLater(Qt.quit);
        }

        surface: WlSessionLockSurface {
            color: "black"

            Timer {
                interval: 400
                running: true
                repeat: true
                onTriggered: {
                    if (!field.activeFocus)
                        field.forceActiveFocus();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 14
                width: 320

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Session locked"
                    color: "white"
                    font.pixelSize: 24
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 8
                    color: "#202020"
                    border.width: 1
                    border.color: root.notice !== "" ? "#ff5555" : "#606060"

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        enabled: !root.busy
                        focus: true
                        clip: true
                        color: "white"
                        font.pixelSize: 18
                        text: root.secret
                        onTextEdited: root.secret = text
                        onAccepted: root.submit()
                        Keys.onPressed: event => {
                            if (event.matches(StandardKey.Paste)
                                || (event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier))) {
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.secret = "";
                                event.accepted = true;
                            }
                        }
                        Component.onCompleted: forceActiveFocus()
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onPressed: field.forceActiveFocus()
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.busy ? "Checking..."
                        : root.notice !== "" ? root.notice
                        : (Quickshell.env("USER") ?? "")
                    color: root.notice !== "" ? "#ff5555" : "#a0a0a0"
                    font.pixelSize: 15
                }
            }
        }
    }
}
