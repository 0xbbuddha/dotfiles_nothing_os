import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The shell's own lock screen, on ext-session-lock.
//
// One surface per monitor, all reading the same Lock singleton, so the
// attempt and the failure are the same everywhere. The compositor keeps
// these surfaces on screen even if the shell dies, which is what makes
// this safe to run: a crash leaves you locked out of the desktop, never
// let in.
Scope {
    id: root

    WlSessionLock {
        id: session
        locked: Lock.locked

        surface: WlSessionLockSurface {
            id: pane
            color: Theme.c.surface

            // Nothing shows through: the desktop behind is never revealed,
            // not even for the frame before the wallpaper decodes.
            Rectangle {
                anchors.fill: parent
                color: Theme.c.surface
            }

            readonly property bool onWallpaper: Config.lockBackground === "wallpaper"

            Image {
                anchors.fill: parent
                visible: pane.onWallpaper
                source: pane.onWallpaper
                    ? Config.wallpaperUrlFor(pane.screen?.width ?? 0,
                                             pane.screen?.height ?? 0)
                    : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }

            // Over a wallpaper the veil is a gradient across the left of
            // the screen and not a flat wash over all of it. Everything
            // that has to be read sits in that band, so the picture stays
            // a picture on the two thirds where nothing is written.
            Rectangle {
                anchors.fill: parent
                visible: pane.onWallpaper
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.82) }
                    GradientStop { position: 0.30; color: Qt.rgba(0, 0, 0, 0.62) }
                    GradientStop { position: 0.62; color: Qt.rgba(0, 0, 0, 0.12) }
                    GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }

            // The dot field is the black look. Laid over a photograph it
            // reads as dirt on the lens rather than as a panel.
            DotField {
                anchors.fill: parent
                visible: !pane.onWallpaper
                step: Theme.px(22)
                dotRadius: Theme.px(1)
                baseAlpha: 0.16
            }

            // Keyboard goes here. A real TextInput rather than raw key
            // handling, so backspace, ctrl+u, held keys and dead keys all
            // behave; its own text is never drawn.
            TextInput {
                id: sink
                anchors.fill: parent
                focus: true
                activeFocusOnPress: false
                echoMode: TextInput.Password
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                enabled: !Lock.busy

                onTextChanged: {
                    if (text !== Lock.secret)
                        Lock.secret = text;
                }

                Connections {
                    target: Lock
                    function onSecretChanged(): void {
                        if (sink.text !== Lock.secret)
                            sink.text = Lock.secret;
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Lock.submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        Lock.clear();
                        event.accepted = true;
                    }
                }

                // The compositor can hand focus to another surface on a
                // monitor change; take it back rather than swallowing keys.
                Timer {
                    interval: 400
                    repeat: true
                    running: Lock.locked
                    onTriggered: if (!sink.activeFocus) sink.forceActiveFocus()
                }
            }

            // Left-aligned, not centred. Centred over a photograph the
            // clock lands on whatever the picture was about; against the
            // left edge it reads as a caption and leaves the subject
            // alone. It costs nothing on the black background either.
            ColumnLayout {
                id: column
                anchors.left: parent.left
                anchors.leftMargin: Math.max(Theme.px(64), parent.width * 0.075)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Theme.px(430), parent.width - Theme.px(96))
                spacing: 0

                // ── Clock ────────────────────────────────────────────
                DisplayText {
                    Layout.alignment: Qt.AlignLeft
                    // Smaller than it was. At 219 the digits ran most of
                    // the way across the screen, which is fine on black
                    // and hopeless over a picture.
                    text: Time.hhmm
                    size: Theme.px(150)
                }

                NLabel {
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: Theme.px(4)
                    // Spaced by inserting the gaps rather than with
                    // letterSpacing, which also pads the last glyph and
                    // leaves the line looking off-centre against the
                    // clock above it.
                    text: Time.dateLong.toUpperCase().split("").join(" ")
                    font.pixelSize: Theme.px(15)
                    font.letterSpacing: 0
                }

                Rectangle {
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: Theme.px(26)
                    width: Theme.px(7)
                    height: width
                    radius: width / 2
                    color: Theme.c.red
                }

                // ── The secret ───────────────────────────────────────
                Rectangle {
                    id: field
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: Theme.px(26)
                    implicitWidth: Theme.px(292)
                    implicitHeight: Theme.px(46)
                    radius: Theme.px(14)
                    color: Theme.c.surface2
                    border.width: 1
                    border.color: Lock.failed ? Theme.c.red : Theme.c.outline
                    clip: true

                    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                    NLabel {
                        anchors.centerIn: parent
                        visible: Lock.secret.length === 0 && !Lock.busy
                        font.pixelSize: Theme.px(13)
                        text: "PASSWORD"
                        color: Theme.c.onFaint
                    }

                    PassDots {
                        anchors.centerIn: parent
                        count: Lock.secret.length
                        alarm: Lock.failed
                        visible: !Lock.busy
                    }

                    // Checking: a single travelling dot, no spinner.
                    Rectangle {
                        id: pulse
                        visible: Lock.busy
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(6)
                        height: width
                        radius: width / 2
                        color: Theme.c.red

                        SequentialAnimation on x {
                            running: Lock.busy
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: Theme.px(20); to: field.width - Theme.px(26)
                                duration: 620; easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: field.width - Theme.px(26); to: Theme.px(20)
                                duration: 620; easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    // Shake on refusal, the one animation worth having.
                    //
                    // Through a transform, never by animating x: the field
                    // is placed by the ColumnLayout, so ending the shake at
                    // x = 0 parked it at the left edge of the column rather
                    // than back in the centre. A transform offsets the
                    // painting and leaves the layout's placement alone.
                    transform: Translate { id: nudge }

                    SequentialAnimation {
                        id: refuse
                        NumberAnimation { target: nudge; property: "x"; to: Theme.px(9); duration: 45 }
                        NumberAnimation { target: nudge; property: "x"; to: -Theme.px(9); duration: 90 }
                        NumberAnimation { target: nudge; property: "x"; to: Theme.px(5); duration: 90 }
                        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
                    }

                    Connections {
                        target: Lock
                        function onShakeChanged(): void { refuse.restart(); }
                    }
                }

                NLabel {
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: Theme.px(10)
                    text: Lock.notice !== "" ? Lock.notice.toUpperCase() : Quickshell.env("USER")
                    font.pixelSize: Theme.px(13)
                    color: Lock.notice !== "" ? Theme.c.red : Theme.c.onFaint
                }

                // ── Fingerprint ──────────────────────────────────────
                // Only when the machine has a reader with something
                // enrolled, so this row simply does not exist elsewhere.
                RowLayout {
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: Theme.px(16)
                    visible: Lock.fingerprint && !Lock.busy
                    spacing: Theme.px(8)

                    NIcon {
                        text: "󰈷"
                        size: Theme.px(15)
                        // The accent while the reader is listening: it is a
                        // live affordance, not a caption.
                        color: Theme.c.red

                        SequentialAnimation on opacity {
                            running: Lock.fingerprint && !Lock.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }

                    NLabel {
                        text: Lock.fingerNotice !== ""
                            ? Lock.fingerNotice.toUpperCase()
                            : "OR TOUCH THE SENSOR"
                        font.pixelSize: Theme.px(12)
                        color: Theme.c.red
                        elide: Text.ElideRight
                        Layout.maximumWidth: Theme.px(280)
                    }
                }

            }

            // ── Session and status, bottom right ─────────────────────
            ColumnLayout {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: Math.max(Theme.px(48), parent.width * 0.05)
                anchors.bottomMargin: Theme.px(46)
                spacing: Theme.px(12)

            // ── Session chips ────────────────────────────────────
            // In the corner, away from the clock. They arm an intent
            // carried out only once PAM has said yes, so they are not
            // controls anyone can press to get anywhere.
            RowLayout {
                spacing: Theme.px(14)

                Repeater {
                    model: [
                        { id: "logout",   icon: "󰗽" },
                        { id: "reboot",   icon: "󰜉" },
                        { id: "poweroff", icon: "󰐥" }
                    ]

                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool armed: Lock.action === chip.modelData.id

                        implicitWidth: Theme.px(46)
                        implicitHeight: Theme.px(40)
                        radius: Theme.px(13)
                        color: chip.armed ? Theme.c.surface3 : Theme.c.surface2
                        border.width: 1
                        border.color: chip.armed ? Theme.c.red : Theme.c.outline

                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                        NIcon {
                            anchors.centerIn: parent
                            text: chip.modelData.icon
                            size: Theme.px(23)
                            color: chip.armed ? Theme.c.red : Theme.c.onDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Lock.arm(chip.modelData.id);
                                sink.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            NLabel {
                Layout.alignment: Qt.AlignRight
                font.pixelSize: Theme.px(12)
                // Only when something is armed. "PASSWORD REQUIRED" said
                // nothing anyone needed, and sitting outside the veil it
                // was unreadable anyway. Armed, it is red and it matters.
                visible: Lock.action !== ""
                text: {
                    switch (Lock.action) {
                    case "logout":   return "LOG OUT AFTER UNLOCK";
                    case "reboot":   return "RESTART AFTER UNLOCK";
                    case "poweroff": return "SHUT DOWN AFTER UNLOCK";
                    default:         return "";
                    }
                }
                color: Theme.c.red
            }
            }

            // ── System line ──────────────────────────────────────────
            // Bottom left, under the column and inside the veil. It sat
            // top right first and was simply unreadable there: over a
            // photograph, faint grey on whatever the picture happens to
            // be is not a colour, it is a guess.
            RowLayout {
                anchors.left: column.left
                anchors.top: column.bottom
                anchors.topMargin: Theme.px(40)
                spacing: Theme.px(18)


                NLabel {
                    text: Sys.kernel !== "" ? "CPU " + Math.round(Sys.cpu * 100) + "%" : ""
                    font.pixelSize: Theme.px(13)
                    color: Theme.c.onFaint
                }
                NLabel {
                    text: Net.kind.toUpperCase()
                    font.pixelSize: Theme.px(13)
                    color: Theme.c.onFaint
                }
                NLabel {
                    text: Player.playing ? "▸  " + Player.cleanTitle : ""
                    visible: text !== ""
                    font.pixelSize: Theme.px(13)
                    color: Theme.c.onFaint
                }
            }
        }
    }

    // Only once PAM said yes.
    Connections {
        target: Lock
        function onGranted(action: string): void {
            // Unlock before acting: the compositor shows an unusable
            // fallback lock if the client goes away while still locked.
            Lock.locked = false;
            Lock.reset();
            switch (action) {
            case "logout":   Power.logout(); break;
            case "reboot":   Power.reboot(); break;
            case "poweroff": Power.poweroff(); break;
            }
        }
    }
}
