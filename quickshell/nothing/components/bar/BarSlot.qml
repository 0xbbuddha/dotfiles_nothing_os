import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../.."
import ".."
import "../../services"

// One element of the bar, chosen by id.
//
// The bar was three islands written out by hand, so the only say the user
// had was a handful of booleans that hid things where they already sat.
// Everything an island can hold lives here instead, and each island is a
// Repeater over its list in Config: what shows, in what order, and in
// which island are all the same kind of edit now.
//
// `bar` is passed down rather than reached for: several elements share
// hover state and timers that belong to the window, and a component that
// walks back up its parents breaks the moment anything wraps it.
Loader {
    id: slot
    required property string itemId
    // Named `win`, not `bar`: as `bar` it shadowed the enclosing window
    // id, so `bar: bar` at the call site assigned the property to itself
    // and every element woke up with it undefined.
    required property var win

    // Whether this element has anything to show, as its own condition
    // rather than as a reading of `visible`.
    //
    // Binding the island's visibility to the slot's looked obvious and
    // deadlocks: `visible` in QML is effective visibility, so the slot
    // reported false because its island was hidden, and the island stayed
    // hidden because the slot reported false. Both settled on false and
    // the whole centre disappeared.
    // Safe to bind here: `applies` is a plain condition, not a reading of
    // visibility, so nothing can loop back through it.
    //
    // The element is kept until the animation has run, so leaving is a
    // movement rather than a disappearance. Recording stopping, an update
    // count falling to zero and a battery going away all used to blink
    // out between two frames.
    // Tested on opacity, not on scale. Scale rests at 0.85 when the
    // element does not apply, so `scale > 0.02` was true for ever: the
    // element stayed invisible but kept its width, and the right island
    // ended in a strip of dead black where privacy and recording were
    // waiting for something to happen. Opacity does reach zero, so the
    // layout closes up behind it.
    visible: slot.applies || slot.opacity > 0.01
    scale: slot.applies ? 1 : 0.85
    opacity: slot.applies ? 1 : 0
    Behavior on scale {
        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    readonly property bool applies: {
        switch (slot.itemId) {
        case "apps":      return Config.appsKey;
        case "essential": return Config.essentialEnabled;
        case "media":     return Player.active;
        case "tray":      return Config.showTray && slot.win.trayItems.length > 0;
        case "cpu":       return Config.barShowCpu;
        case "ram":       return Config.barShowRam;
        case "gpu":       return Config.barShowGpu && Sys.gpuSeen;
        case "temp":      return Config.barShowTemp && Sys.cpuTemp > 0;
        case "updates":   return Updates.available && Updates.count > 0;
        case "mic":       return Audio.hasMic;
        case "battery":   return slot.win.hasBatt;
        case "notifications": return Config.notificationsEnabled;
        case "privacy":   return Privacy.any;
        case "recording": return Recorder.recording;
        case "window":    return (Hyprland.activeToplevel?.title ?? "") !== "";
        default:          return true;
        }
    }

    sourceComponent: {
        switch (slot.itemId) {
        case "workspaces": return workspacesPart;
        case "media":      return mediaPart;
        case "window":     return windowPart;
        case "apps":       return appsPart;
        case "clock":      return clockPart;
        case "essential":  return essentialPart;
        case "tray":       return trayPart;
        case "net":        return netPart;
        case "bluetooth":  return btPart;
        case "cpu":        return cpuPart;
        case "ram":        return ramPart;
        case "gpu":        return gpuPart;
        case "temp":       return tempPart;
        case "updates":    return updatesPart;
        case "mic":        return micPart;
        case "volume":     return volumePart;
        case "battery":    return batteryPart;
        case "notifications": return bellPart;
        case "privacy":    return privacyPart;
        case "recording":  return recordingPart;
        default:           return null;
        }
    }

    // ── Workspaces ────────────────────────────────────────────────────
    Component {
        id: workspacesPart
        WorkspaceStrip {
            Layout.alignment: Qt.AlignVCenter
            monitorName: slot.win.screen?.name ?? ""
        }
    }

    // ── Now playing ───────────────────────────────────────────────────
    Component {
        id: mediaPart
        Item {
            id: mediaBox
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Theme.px(136)
            Layout.maximumWidth: Theme.px(136)
            implicitWidth: Theme.px(136)
            implicitHeight: mediaRow.implicitHeight
            visible: Player.active

            readonly property bool hovered: mediaMa.containsMouse
            onHoveredChanged: slot.win.holdMedia(hovered)

            Row {
                id: mediaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(6)

                NIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Player.playing ? "󰐊" : "󰏤"
                    size: Theme.px(10)
                    color: Player.playing ? Theme.c.red : Theme.c.onDim
                }

                NText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(120)
                    text: Player.cleanTitle
                    color: Theme.c.onDim
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: mediaMa
                anchors.fill: parent
                anchors.margins: -Theme.px(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) Player.next();
                    else Player.playPause();
                }
            }
        }
    }

    // ── Focused window ────────────────────────────────────────────────
    // New. The one thing a bar of this shape was missing, and the reason
    // the left island looked empty whenever nothing was playing.
    Component {
        id: windowPart
        NText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Theme.px(220)
            text: Hyprland.activeToplevel?.title ?? ""
            visible: text !== ""
            color: Theme.c.onDim
            elide: Text.ElideRight
        }
    }

    // ── Essential Apps ────────────────────────────────────────────────
    // A dot grid rather than an icon-font glyph: it keeps the same pitch
    // as the Glyph Matrix and the settings rail.
    Component {
        id: appsPart
        Item {
            implicitWidth: Theme.z.bar
            implicitHeight: Theme.z.bar
            visible: Config.appsKey

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: Theme.px(3)

                Repeater {
                    model: 4
                    Rectangle {
                        width: Theme.px(4)
                        height: width
                        radius: Theme.px(1)
                        color: (GlobalState.appsOpen || appsMa.containsMouse)
                            ? Theme.c.red : Theme.c.onDim
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }
                }
            }

            scale: appsMa.pressed ? 0.92 : 1
            Behavior on scale {
                NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad }
            }

            MouseArea {
                id: appsMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (GlobalState.appsOpen) {
                        GlobalState.appsOpen = false;
                        return;
                    }
                    GlobalState.closeAll();
                    GlobalState.appsOpen = true;
                }
            }

            Tooltip {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: Theme.px(8)
                text: "Essential Apps"
                shown: appsMa.containsMouse && !GlobalState.appsOpen
            }
        }
    }

    // ── Clock ─────────────────────────────────────────────────────────
    Component {
        id: clockPart
        Item {
            implicitWidth: clockText.implicitWidth + Theme.px(28)
            implicitHeight: Theme.z.bar

            DisplayText {
                id: clockText
                anchors.centerIn: parent
                text: Time.hhmm
                size: Theme.px(20)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) GlobalState.toggleLauncher();
                    else slot.win.openCc();
                }
                onWheel: (w) => {
                    if (!Audio.audio) return;
                    const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
                    Audio.audio.volume =
                        Math.max(0, Math.min(1, Audio.audio.volume + step));
                }
            }

            // The underline that says the control centre is down. Read
            // from GlobalState rather than from the panel's id: the clock
            // is no longer written next to it.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: GlobalState.controlCenterOpen ? parent.width * 0.55 : 0
                height: Theme.px(2)
                radius: height / 2
                color: Theme.c.red
                Behavior on width {
                    NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                }
            }
        }
    }

    // ── Essential Key ─────────────────────────────────────────────────
    // Click captures, double-click opens, hold talks. The click counter
    // and the hold flag live on the window because the tooltip and the
    // timer both read them.
    Component {
        id: essentialPart
        Item {
            implicitWidth: Theme.z.bar
            implicitHeight: Theme.z.bar
            visible: Config.essentialEnabled

            Rectangle {
                id: essentialKey
                anchors.centerIn: parent
                width: Theme.px(7)
                height: Theme.px(16)
                radius: width / 2
                color: Voice.recording ? Theme.c.red : "transparent"
                border.width: Theme.px(1.5)
                border.color: {
                    if (Voice.recording || GlobalState.essentialPulse
                            || GlobalState.essentialOpen
                            || essentialMa.containsMouse)
                        return Theme.c.red;
                    return Theme.c.onDim;
                }
                Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                scale: Voice.recording ? 1.2
                     : (GlobalState.essentialPulse ? 1.35 : 1)
                Behavior on scale {
                    NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.px(3)
                    width: Theme.px(2)
                    height: Theme.px(2)
                    radius: width / 2
                    color: parent.border.color
                    visible: !Voice.recording
                }

                SequentialAnimation on opacity {
                    running: Voice.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 520 }
                    NumberAnimation { to: 1.0; duration: 520 }
                    onRunningChanged: if (!running) essentialKey.opacity = 1
                }
            }

            Timer {
                id: essentialClickWait
                interval: 280
                onTriggered: {
                    slot.win.essentialClicks = 0;
                    Essentials.keyShot();
                }
            }

            MouseArea {
                id: essentialMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                pressAndHoldInterval: 500
                onPressed: {
                    slot.win.essentialHeld = false;
                    essentialClickWait.stop();
                }
                onPressAndHold: {
                    slot.win.essentialHeld = true;
                    essentialClickWait.stop();
                    slot.win.essentialClicks = 0;
                    if (Voice.recording)
                        Essentials.stopVoice();
                    else
                        Essentials.startVoice();
                }
                onClicked: {
                    if (slot.win.essentialHeld)
                        return;
                    if (Voice.recording) {
                        Essentials.stopVoice();
                        return;
                    }
                    slot.win.essentialClicks += 1;
                    if (slot.win.essentialClicks >= 2) {
                        essentialClickWait.stop();
                        slot.win.essentialClicks = 0;
                        if (GlobalState.essentialOpen)
                            GlobalState.essentialOpen = false;
                        else {
                            GlobalState.closeAll();
                            GlobalState.essentialOpen = true;
                        }
                    } else {
                        essentialClickWait.restart();
                    }
                }
            }

            Tooltip {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: Theme.px(8)
                text: Voice.recording
                    ? ("Recording " + Voice.timecode() + " \u00b7 click to save")
                    : "Click to capture \u00b7 double-click to open \u00b7 hold to talk"
                shown: essentialMa.containsMouse
                enabled: false
            }
        }
    }

    // ── System tray ───────────────────────────────────────────────────
    Component {
        id: trayPart
        Row {
            spacing: Theme.px(7)

            Repeater {
                model: slot.win.trayItems

                Item {
                    id: trayItem
                    required property var modelData
                    width: Theme.px(13)
                    height: Theme.px(13)
                    anchors.verticalCenter: parent.verticalCenter

                    AppIcon {
                        anchors.fill: parent
                        appId: Apps.trayKey(trayItem.modelData)
                        iconName: trayItem.modelData.icon
                        size: parent.width
                        opacity: tma.containsMouse ? 1 : 0.7
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    }

                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        anchors.margins: -Theme.px(3)
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                const pt = trayItem.mapToItem(null, 0, 0);
                                trayItem.modelData.display(slot.win, pt.x,
                                    Theme.z.bar + Theme.px(13));
                            } else {
                                trayItem.modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Network and Bluetooth ─────────────────────────────────────────
    Component {
        id: netPart
        BarStat {
            icon: Net.glyph
            showValue: false
            accent: Net.kind === "none" ? Theme.c.onFaint : Theme.c.on
            onActivated: GlobalState.openNet("wifi")
            onSecondary: GlobalState.openNet("wifi")
        }
    }

    Component {
        id: btPart
        BarStat {
            icon: Net.btConnected.length > 0 ? "󰂱" : "󰂯"
            showValue: false
            accent: Net.btPowered ? Theme.c.on : Theme.c.onFaint
            onActivated: GlobalState.openNet("bt")
            onSecondary: GlobalState.openNet("bt")
        }
    }

    // ── The four gauges ───────────────────────────────────────────────
    // Each one its own element now, so any of them can be dropped or
    // moved on its own. Hovering any of them still opens the same recap:
    // they hold it through the window rather than by being grouped.
    Component {
        id: cpuPart
        BarStat {
            icon: "󰻠"
            value: Math.round(Sys.cpu * 100) + "%"
            valueHint: "100%"
            accent: Sys.cpu > 0.85 ? Theme.c.red : Theme.c.onDim
            onActivated: slot.win.openCc()
            onHoveredChanged: slot.win.holdRecap(hovered)
        }
    }

    Component {
        id: ramPart
        BarStat {
            icon: "󰍛"
            value: Math.round(Sys.ram * 100) + "%"
            valueHint: "100%"
            accent: Sys.ram > 0.9 ? Theme.c.red : Theme.c.onDim
            onActivated: slot.win.openCc()
            onHoveredChanged: slot.win.holdRecap(hovered)
        }
    }

    Component {
        id: gpuPart
        BarStat {
            icon: "󰢮"
            value: Math.round(Sys.gpu * 100) + "%"
            valueHint: "100%"
            accent: Sys.gpu > 0.85 ? Theme.c.red : Theme.c.onDim
            onActivated: slot.win.openCc()
            onHoveredChanged: slot.win.holdRecap(hovered)
        }
    }

    Component {
        id: tempPart
        BarStat {
            icon: Sys.hot ? "󰸁" : "󰔐"
            value: Sys.cpuTemp + "\u00b0"
            valueHint: "100\u00b0"
            accent: Sys.hot ? Theme.c.red : Theme.c.onDim
            onActivated: slot.win.openCc()
            onHoveredChanged: slot.win.holdRecap(hovered)
        }
    }

    // ── Updates, microphone, volume ───────────────────────────────────
    Component {
        id: updatesPart
        BarStat {
            icon: "󰚰"
            value: Updates.count > 99 ? "99+" : Updates.count
            valueHint: "99+"
            accent: Updates.urgent ? Theme.c.red : Theme.c.on
            onActivated: Updates.install()
        }
    }

    Component {
        id: micPart
        BarStat {
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            showValue: false
            accent: Audio.micMuted ? Theme.c.red : Theme.c.on
            onActivated: Audio.toggleMic()
        }
    }

    Component {
        id: volumePart
        BarStat {
            icon: Audio.muted ? "󰝟" : (Audio.volume > 0.5 ? "󰕾" : "󰖀")
            value: Math.round(Audio.volume * 100) + "%"
            valueHint: "100%"
            accent: Audio.muted ? Theme.c.red : Theme.c.on
            onActivated: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
            onSecondary: GlobalState.openAudio()
            onScrolled: (d) => {
                if (!Audio.audio) return;
                Audio.audio.volume =
                    Math.max(0, Math.min(1, Audio.audio.volume + d * 0.05));
            }
        }
    }

    // ── Battery ───────────────────────────────────────────────────────
    Component {
        id: batteryPart
        BarStat {
            icon: (slot.win.batt?.state === UPowerDeviceState.Charging)
                ? "󰂄" : "󰁹"
            value: Math.round((slot.win.batt?.percentage ?? 0) * 100) + "%"
            valueHint: "100%"
            accent: (slot.win.batt?.percentage ?? 1) < 0.2 ? Theme.c.red : Theme.c.on
            onHoveredChanged: slot.win.holdBatt(hovered)
        }
    }

    // ── Notifications ─────────────────────────────────────────────────
    Component {
        id: bellPart
        Item {
            implicitWidth: Theme.px(22)
            implicitHeight: Theme.px(14)
            z: 1

            NIcon {
                anchors.centerIn: parent
                size: Theme.px(11)
                text: Notifs.doNotDisturb ? "󰂛" : "󰂚"
                color: bellMa.containsMouse ? Theme.c.on : Theme.c.onDim
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -Theme.px(2)
                visible: Notifs.unread > 0
                implicitWidth: Math.max(Theme.px(11),
                                        badgeTxt.implicitWidth + Theme.px(5))
                implicitHeight: Theme.px(11)
                radius: height / 2
                color: Theme.c.red

                Text {
                    id: badgeTxt
                    anchors.centerIn: parent
                    text: Notifs.unread > 9 ? "9+" : String(Notifs.unread)
                    color: Theme.c.onAccent
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.micro
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: bellMa
                anchors.fill: parent
                anchors.margins: -Theme.px(3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        Notifs.doNotDisturb = !Notifs.doNotDisturb;
                        return;
                    }
                    if (GlobalState.notifCenterOpen) {
                        GlobalState.notifCenterOpen = false;
                        return;
                    }
                    GlobalState.closeAll();
                    GlobalState.notifCenterOpen = true;
                }
            }
        }
    }

    // ── Privacy ───────────────────────────────────────────────────────
    Component {
        id: privacyPart
        Row {
            spacing: Theme.px(6)

            Repeater {
                model: [
                    { on: Privacy.micActive,    icon: "󰍬", label: "Microphone" },
                    { on: Privacy.cameraActive, icon: "󰄀", label: "Camera" },
                    { on: Privacy.screenActive, icon: "󰍹", label: "Screen sharing" }
                ]

                Item {
                    id: priv
                    required property var modelData
                    visible: modelData.on
                    width: visible ? Theme.px(13) : 0
                    height: Theme.px(13)
                    anchors.verticalCenter: parent.verticalCenter

                    NIcon {
                        anchors.centerIn: parent
                        text: priv.modelData.icon
                        size: Theme.px(11)
                        color: Theme.c.red

                        SequentialAnimation on opacity {
                            running: priv.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 1100
                                              easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 1100
                                              easing.type: Easing.InOutQuad }
                        }
                    }

                    MouseArea {
                        id: privMa
                        anchors.fill: parent
                        anchors.margins: -Theme.px(3)
                        hoverEnabled: true
                    }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: Theme.px(8)
                        text: {
                            const who = Privacy.users();
                            return who !== ""
                                ? priv.modelData.label + " \u00b7 " + who
                                : priv.modelData.label + " in use";
                        }
                        shown: privMa.containsMouse
                    }
                }
            }
        }
    }

    // ── Recording ─────────────────────────────────────────────────────
    Component {
        id: recordingPart
        Item {
            implicitWidth: rec.implicitWidth
            implicitHeight: rec.implicitHeight

            Row {
                id: rec
                anchors.centerIn: parent
                spacing: Theme.px(5)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(7); height: width; radius: width / 2
                    color: Theme.c.red

                    SequentialAnimation on opacity {
                        running: Recorder.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 700 }
                        NumberAnimation { to: 1.0;  duration: 700 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.timecode()
                    color: Theme.c.red
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.small
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.px(4)
                cursorShape: Qt.PointingHandCursor
                onClicked: Recorder.stop()
            }
        }
    }
}
