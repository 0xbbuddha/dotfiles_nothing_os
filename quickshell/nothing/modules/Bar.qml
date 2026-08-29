import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import ".."
import "../components"
import "../services"

// Four independent islands. The clock and Essential Key sit together at
// the centre of the screen; workspaces and the CC stay on the edges.
//
// The CC and flyouts live on a separate layer. Growing the bar window
// reconfigures the Hyprland layer and the navbar blinks as if it were
// reloading.
Item {
    id: root
    required property var modelData

PanelWindow {
    id: bar

    screen: root.modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nothing-bar"

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.z.barWin
    exclusiveZone: Theme.z.bar + Theme.px(9)

    mask: Region {
        intersection: Intersection.Combine
        regions: [
            Region { item: leftIsland },
            // The bar only takes clicks where an island is. A new one has
            // to be listed here or it is drawn but not clickable.
            Region { item: appsIsland.visible ? appsIsland : null },
            Region { item: clockIsland },
            Region { item: keyIsland.visible ? keyIsland : null },
            Region { item: rightIsland }
        ]
    }

    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: (batt?.isLaptopBattery ?? false) && Config.showBattery
    readonly property var trayItems: SystemTray.items?.values ?? []
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (root.modelData?.name ?? "")

    readonly property int edge: Theme.px(10)
    readonly property int islandGap: Theme.px(12)
    readonly property real midX: (width - midCluster.width) / 2
    readonly property real leftMax: Math.max(Theme.px(72), midX - edge - islandGap)
    readonly property real rightMax: Math.max(Theme.px(72),
        width - edge - midX - midCluster.width - islandGap)

    function openCc(): void {
        GlobalState.controlCenterOpen = !GlobalState.controlCenterOpen;
    }

    property bool recapKeep: false
    property bool battKeep: false
    property bool mediaKeep: false
    property int essentialClicks: 0
    property bool essentialHeld: false
    Timer {
        id: recapHide
        interval: 220
        onTriggered: bar.recapKeep = false
    }
    Timer {
        id: battHide
        interval: 220
        onTriggered: bar.battKeep = false
    }
    Timer {
        id: mediaHide
        interval: 220
        onTriggered: bar.mediaKeep = false
    }

    // ── Left: workspaces + media ──────────────────────────────────────
    BarIsland {
        id: leftIsland
        anchors.left: parent.left
        anchors.leftMargin: bar.edge
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        width: Math.min(implicitWidth, bar.leftMax)
        visible: Config.showWorkspaces || Player.active
        onActivated: bar.openCc()
        onSecondary: GlobalState.toggleLauncher()

        WorkspaceStrip {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.showWorkspaces
            monitorName: root.modelData?.name ?? ""
        }

        BarSeparator { visible: Config.showWorkspaces && Player.active }

        Item {
            id: mediaBox
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Theme.px(136)
            Layout.maximumWidth: Theme.px(136)
            implicitWidth: Theme.px(136)
            implicitHeight: mediaRow.implicitHeight
            visible: Player.active
            readonly property bool hovered:
                mediaMa.containsMouse || mediaRecap.hovered

            onHoveredChanged: {
                if (hovered) {
                    mediaHide.stop();
                    bar.mediaKeep = true;
                } else {
                    mediaHide.restart();
                }
            }

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

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(120)
                    text: Player.cleanTitle
                    color: Theme.c.onDim
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.small
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

    // ── Centre: Essential Apps, clock, Essential Key, centred together ─
    Item {
        id: midCluster
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        height: Theme.z.bar
        width: (appsIsland.visible ? appsIsland.width + bar.islandGap : 0)
            + clockIsland.width
            + (keyIsland.visible ? bar.islandGap + keyIsland.width : 0)

        // Left of the clock, the Essential Key being on its right. Drawn
        // as a dot grid rather than an icon-font glyph: it keeps the same
        // pitch as the Glyph Matrix and the settings rail.
        NCard {
            id: appsIsland
            visible: Config.appsKey
            anchors.left: parent.left
            anchors.top: parent.top
            radius: Theme.r.pill
            height: Theme.z.bar
            width: Theme.z.bar

            Grid {
                id: appsDots
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
            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutQuad } }

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

        NCard {
            id: clockIsland
            anchors.left: appsIsland.visible ? appsIsland.right : parent.left
            anchors.leftMargin: appsIsland.visible ? bar.islandGap : 0
            anchors.top: parent.top
            radius: Theme.r.pill
            height: Theme.z.bar
            width: clockText.implicitWidth + Theme.px(28)

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
                else bar.openCc();
            }
            onWheel: (w) => {
                if (!Audio.audio) return;
                const step = w.angleDelta.y > 0 ? 0.05 : -0.05;
                Audio.audio.volume = Math.max(0, Math.min(1, Audio.audio.volume + step));
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: cc.open ? parent.width * 0.55 : 0
            height: Theme.px(2)
            radius: height / 2
            color: Theme.c.red
            Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
        }
        }

        NCard {
            id: keyIsland
            visible: Config.essentialEnabled
            anchors.left: clockIsland.right
            anchors.leftMargin: bar.islandGap
            anchors.top: parent.top
            radius: Theme.r.pill
            height: Theme.z.bar
            width: Theme.z.bar

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
                bar.essentialClicks = 0;
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
                bar.essentialHeld = false;
                essentialClickWait.stop();
            }
            onPressAndHold: {
                bar.essentialHeld = true;
                essentialClickWait.stop();
                bar.essentialClicks = 0;
                if (Voice.recording)
                    Essentials.stopVoice();
                else
                    Essentials.startVoice();
            }
            onClicked: {
                if (bar.essentialHeld)
                    return;
                if (Voice.recording) {
                    Essentials.stopVoice();
                    return;
                }
                bar.essentialClicks += 1;
                if (bar.essentialClicks >= 2) {
                    essentialClickWait.stop();
                    bar.essentialClicks = 0;
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
                ? ("Recording " + Voice.timecode() + " · click to save")
                : "Click to capture · double-click to open · hold to talk"
            shown: essentialMa.containsMouse
            enabled: false
        }
        }
    }

    // ── Right: tray, stats, sound, battery ────────────────────────────
    BarIsland {
        id: rightIsland
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        anchors.top: parent.top
        anchors.topMargin: Theme.px(5)
        width: Math.min(implicitWidth, bar.rightMax)
        onActivated: bar.openCc()
        onSecondary: GlobalState.toggleLauncher()
        onScrolled: (d) => {
            if (!Audio.audio) return;
            Audio.audio.volume = Math.max(0, Math.min(1, Audio.audio.volume + d * 0.05));
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.px(7)
            visible: Config.showTray && bar.trayItems.length > 0

            Repeater {
                model: bar.trayItems

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
                                const p = trayItem.mapToItem(null, 0, 0);
                                trayItem.modelData.display(bar, p.x,
                                    rightIsland.y + rightIsland.height + Theme.px(8));
                            } else {
                                trayItem.modelData.activate();
                            }
                        }
                    }
                }
            }
        }

        BarSeparator { visible: Config.showTray && bar.trayItems.length > 0 }

        BarStat {
            icon: Net.glyph
            showValue: false
            accent: Net.kind === "none" ? Theme.c.onFaint : Theme.c.on
            onActivated: GlobalState.openNet("wifi")
            onSecondary: GlobalState.openNet("wifi")
        }

        BarStat {
            icon: Net.btConnected.length > 0 ? "󰂱" : "󰂯"
            showValue: false
            accent: Net.btPowered ? Theme.c.on : Theme.c.onFaint
            onActivated: GlobalState.openNet("bt")
            onSecondary: GlobalState.openNet("bt")
        }

        Item {
            id: statsBox
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: statsRow.implicitWidth
            implicitHeight: statsRow.implicitHeight
            visible: cpuStat.visible || ramStat.visible || gpuStat.visible || tempStat.visible
            readonly property bool hovered:
                cpuStat.hovered || ramStat.hovered || gpuStat.hovered
                || tempStat.hovered || recap.hovered

            onHoveredChanged: {
                if (hovered) {
                    recapHide.stop();
                    bar.recapKeep = true;
                } else {
                    recapHide.restart();
                }
            }

            Row {
                id: statsRow
                spacing: Theme.px(10)

                BarStat {
                    id: cpuStat
                    icon: "󰻠"
                    value: Math.round(Sys.cpu * 100) + "%"
                    valueHint: "100%"
                    accent: Sys.cpu > 0.85 ? Theme.c.red : Theme.c.onDim
                    visible: Config.barShowCpu
                    onActivated: bar.openCc()
                }

                BarStat {
                    id: ramStat
                    icon: "󰍛"
                    value: Math.round(Sys.ram * 100) + "%"
                    valueHint: "100%"
                    accent: Sys.ram > 0.9 ? Theme.c.red : Theme.c.onDim
                    visible: Config.barShowRam
                    onActivated: bar.openCc()
                }

                BarStat {
                    id: gpuStat
                    icon: "󰢮"
                    value: Math.round(Sys.gpu * 100) + "%"
                    valueHint: "100%"
                    accent: Sys.gpu > 0.85 ? Theme.c.red : Theme.c.onDim
                    visible: Config.barShowGpu && Sys.gpuSeen
                    onActivated: bar.openCc()
                }

                BarStat {
                    id: tempStat
                    icon: Sys.hot ? "󰸁" : "󰔐"
                    value: Sys.cpuTemp + "°"
                    valueHint: "100°"
                    accent: Sys.hot ? Theme.c.red : Theme.c.onDim
                    visible: Config.barShowTemp && Sys.cpuTemp > 0
                    onActivated: bar.openCc()
                }
            }
        }

        BarStat {
            icon: "󰚰"
            value: Updates.count > 99 ? "99+" : Updates.count
            valueHint: "99+"
            accent: Updates.urgent ? Theme.c.red : Theme.c.on
            visible: Updates.available && Updates.count > 0
            onActivated: Updates.install()
        }

        BarStat {
            icon: Audio.micMuted ? "󰍭" : "󰍬"
            showValue: false
            accent: Audio.micMuted ? Theme.c.red : Theme.c.on
            visible: Audio.hasMic
            onActivated: Audio.toggleMic()
        }

        BarStat {
            icon: Audio.muted ? "󰝟" : (Audio.volume > 0.5 ? "󰕾" : "󰖀")
            value: Math.round(Audio.volume * 100) + "%"
            valueHint: "100%"
            accent: Audio.muted ? Theme.c.red : Theme.c.on
            onActivated: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
            onSecondary: GlobalState.openAudio()
            onScrolled: (d) => {
                if (!Audio.audio) return;
                Audio.audio.volume = Math.max(0, Math.min(1, Audio.audio.volume + d * 0.05));
            }
        }

        Item {
            id: battBox
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: battStat.implicitWidth
            implicitHeight: battStat.implicitHeight
            visible: bar.hasBatt
            readonly property bool hovered:
                battStat.hovered || battRecap.hovered

            onHoveredChanged: {
                if (hovered) {
                    battHide.stop();
                    bar.battKeep = true;
                } else {
                    battHide.restart();
                }
            }

            BarStat {
                id: battStat
                icon: (bar.batt?.state === UPowerDeviceState.Charging) ? "󰂄" : "󰁹"
                value: Math.round((bar.batt?.percentage ?? 0) * 100) + "%"
                valueHint: "100%"
                accent: (bar.batt?.percentage ?? 1) < 0.2 ? Theme.c.red : Theme.c.on
            }
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.px(6)
            visible: Privacy.any

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
                            NumberAnimation { to: 0.4; duration: 1100; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutQuad }
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
                                ? priv.modelData.label + " · " + who
                                : priv.modelData.label + " in use";
                        }
                        shown: privMa.containsMouse
                    }
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            visible: Recorder.recording
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

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Theme.px(22)
            Layout.preferredHeight: Theme.px(14)
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
                implicitWidth: Math.max(Theme.px(11), badgeTxt.implicitWidth + Theme.px(5))
                implicitHeight: Theme.px(11)
                radius: height / 2
                color: Theme.c.red

                Text {
                    id: badgeTxt
                    anchors.centerIn: parent
                    text: Notifs.unread > 9 ? "9+" : String(Notifs.unread)
                    color: Theme.c.surface
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

    }

    PanelWindow {
        id: dropLayer
        screen: root.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nothing-overlay"
        anchors { top: true; left: true; right: true }
        implicitHeight: screen.height
        exclusiveZone: -1
        exclusionMode: ExclusionMode.Ignore

        readonly property int dropY: Theme.px(5) + Theme.z.bar + Theme.px(8)

        mask: Region {
            intersection: Intersection.Combine
            regions: [
                Region { item: cc.open ? cc : null },
                Region { item: recap.shown ? recap : null },
                Region { item: battRecap.shown ? battRecap : null },
                Region { item: mediaRecap.shown ? mediaRecap : null },
                Region { item: flyout.open ? flyout : null },
                Region { item: audioFlyout.open ? audioFlyout : null },
                Region { item: lightFlyout.open ? lightFlyout : null }
            ]
        }

    ControlCenter {
        id: cc
        open: GlobalState.controlCenterOpen && bar.onFocusedMonitor
        maxHeight: bar.screen.height - Theme.px(20) - Theme.z.barWin - Theme.px(8)
        onRequestClose: GlobalState.controlCenterOpen = false
        onOpenChanged: if (open) {
            GlobalState.netPanel = "";
            GlobalState.audioPanel = false;
            GlobalState.lightPanel = false;
        }
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.horizontalCenter: parent.horizontalCenter
    }

    NetFlyout {
        id: flyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    AudioFlyout {
        id: audioFlyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    BrightnessFlyout {
        id: lightFlyout
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
        visible: bar.onFocusedMonitor && (open || opacity > 0.01)
    }

    SysRecap {
        id: recap
        shown: bar.recapKeep && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
    }

    BattRecap {
        id: battRecap
        batt: bar.batt
        shown: bar.battKeep && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        anchors.right: parent.right
        anchors.rightMargin: bar.edge
    }

    MediaRecap {
        id: mediaRecap
        shown: bar.mediaKeep && Player.active && !cc.open && !flyout.open && !audioFlyout.open && !lightFlyout.open && bar.onFocusedMonitor
        anchors.top: parent.top
        anchors.topMargin: dropLayer.dropY
        x: leftIsland.x + leftIsland.width - width
    }

    HyprlandFocusGrab {
        active: (cc.open || flyout.open || audioFlyout.open || lightFlyout.open) && bar.onFocusedMonitor
        windows: [bar, dropLayer]
        onCleared: {
            GlobalState.controlCenterOpen = false;
            GlobalState.netPanel = "";
            GlobalState.audioPanel = false;
            GlobalState.lightPanel = false;
        }
    }
    }
}
