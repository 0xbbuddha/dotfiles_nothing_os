import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../components/game"
import "../services"

// Game overlay. SUPER+G opens the editor: place HUDs, snap them, pin them.
// Closed, only pinned widgets stay above the game, and only if they do
// not have click-through.
PanelWindow {
    id: win
    required property var modelData

    readonly property bool editing: GlobalState.gameBarOpen && onFocusedMonitor
        && !Recorder.picking && !Recorder.recording
        && !Shot.picking
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    readonly property string screenName: modelData?.name ?? ""

    readonly property var widgets: (Config.gameWidgets ?? []).filter(w => {
        const m = w.monitor ?? "";
        return m === "" || m === win.screenName;
    })
    readonly property var pinned: widgets.filter(w => w.pinned)

    property var clickableItems: []
    property real guideX: -1
    property real guideY: -1

    function setClickable(item: var, on: bool): void {
        const without = win.clickableItems.filter(x => x !== item);
        win.clickableItems = on ? without.concat([item]) : without;
    }

    function place(id: string): void {
        if (Config.gameWidgetEnabled(id)) {
            Config.removeGameWidget(id);
            if (GlobalState.gameSelected === id)
                GlobalState.gameSelected = "";
            return;
        }
        const meta = GameRegistry.meta(id);
        const n = win.widgets.length;
        Config.addGameWidget(id,
            Theme.px(72) + n * Theme.px(28),
            Theme.px(72) + n * Theme.px(28),
            Theme.px(meta?.w ?? 240), Theme.px(meta?.h ?? 140),
            win.screenName);
        GlobalState.gameSelected = id;
    }

    function cycleCrosshair(): void {
        const styles = ["cross", "dot", "circle", "crossdot", "tshape"];
        const i = styles.indexOf(Config.crosshairStyle);
        Config.crosshairStyle = styles[(i + 1) % styles.length];
        Config.crosshair = true;
        Config.save();
    }

    screen: modelData
    color: "transparent"
    visible: !Recorder.picking && !Shot.picking
        && (win.editing || win.pinned.length > 0 || Recorder.recording)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-gamebar"
    WlrLayershell.keyboardFocus: editing
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    mask: win.editing ? null : pinnedMask

    Component { id: regionComponent; Region {} }

    Region {
        id: pinnedMask
        intersection: Intersection.Combine
        regions: win.clickableItems.map(
            (w) => regionComponent.createObject(win, { item: w }))
    }

    onEditingChanged: if (!editing) {
        GlobalState.gameSelected = "";
        win.guideX = -1;
        win.guideY = -1;
    }

    // ── Scrim ─────────────────────────────────────────────────────────
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.shade(0.5)
        opacity: win.editing ? 1 : 0
        visible: win.editing || opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (GlobalState.gameSelected !== "")
                    GlobalState.gameSelected = "";
                else
                    GlobalState.gameBarOpen = false;
            }
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: win.editing
        Keys.onPressed: (e) => {
            if (!win.editing) return;
            const id = GlobalState.gameSelected;
            if (e.key === Qt.Key_Escape) {
                if (id !== "") GlobalState.gameSelected = "";
                else GlobalState.gameBarOpen = false;
                e.accepted = true;
            } else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && id !== "") {
                Config.removeGameWidget(id);
                GlobalState.gameSelected = "";
                e.accepted = true;
            } else if (e.key === Qt.Key_P && id !== "") {
                const w = Config.gameWidget(id);
                Config.updateGameWidget(id, { pinned: !(w?.pinned ?? false) });
                e.accepted = true;
            } else if (e.key === Qt.Key_G && id !== "") {
                const w = Config.gameWidget(id);
                Config.updateGameWidget(id, { clickthrough: !(w?.clickthrough ?? false) });
                e.accepted = true;
            }
        }
    }

    // ── Snap guides ───────────────────────────────────────────────────
    Rectangle {
        visible: win.editing && win.guideX >= 0
        x: win.guideX
        width: 1
        height: parent.height
        color: Theme.c.red
        opacity: 0.55
        z: 20
    }

    Rectangle {
        visible: win.editing && win.guideY >= 0
        y: win.guideY
        width: parent.width
        height: 1
        color: Theme.c.red
        opacity: 0.55
        z: 20
    }

    // ── Canvas ────────────────────────────────────────────────────────
    Item {
        id: canvas
        anchors.fill: parent

        Repeater {
            model: win.widgets

            GameWidget {
                id: gw
                required property var modelData
                wid: modelData.id
                host: win
                editing: win.editing

                Loader {
                    anchors.fill: parent
                    sourceComponent: {
                        switch (gw.wid) {
                        case "resources": return cRes;
                        case "fps":       return cFps;
                        case "recorder":  return cRec;
                        case "mixer":     return cMix;
                        case "notes":     return cNotes;
                        case "clock":     return cClock;
                        case "image":     return cImage;
                        default:          return null;
                        }
                    }
                }
            }
        }
    }

    Component { id: cRes;   GResources {} }
    Component { id: cFps;   GFps {} }
    Component { id: cRec;   GRecorder {} }
    Component { id: cMix;   GMixer {} }
    Component { id: cNotes; GNotes {} }
    Component { id: cClock; GClock {} }
    Component { id: cImage; GImage {} }

    // ── Inspector for the selected widget ─────────────────────────────
    NCard {
        id: inspector
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: rail.top
        anchors.bottomMargin: Theme.px(10)
        radius: Theme.r.pill
        implicitWidth: inspRow.implicitWidth + Theme.px(20)
        implicitHeight: Theme.px(36)
        opacity: win.editing && GlobalState.gameSelected !== "" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        readonly property var sel: Config.gameWidget(GlobalState.gameSelected)

        Row {
            id: inspRow
            anchors.centerIn: parent
            spacing: Theme.px(10)

            NLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: GameRegistry.meta(GlobalState.gameSelected)?.label ?? ""
                dim: false
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: Theme.px(12)
                color: Theme.c.outline
            }

            CircleButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: inspector.sel?.pinned ? "󰐃" : "󰤱"
                size: Theme.px(22)
                filled: inspector.sel?.pinned ?? false
                onActivated: if (GlobalState.gameSelected !== "")
                    Config.updateGameWidget(GlobalState.gameSelected,
                        { pinned: !(inspector.sel?.pinned ?? false) })
            }

            CircleButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: inspector.sel?.clickthrough ? "󰈈" : "󰈉"
                size: Theme.px(22)
                filled: inspector.sel?.clickthrough ?? false
                onActivated: if (GlobalState.gameSelected !== "")
                    Config.updateGameWidget(GlobalState.gameSelected,
                        { clickthrough: !(inspector.sel?.clickthrough ?? false) })
            }

            NSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(88)
                value: inspector.sel?.opacity ?? 1
                accent: Theme.c.on
                onMoved: (v) => {
                    if (GlobalState.gameSelected === "") return;
                    Config.updateGameWidget(GlobalState.gameSelected, {
                        opacity: Math.round(Math.max(0.35, v) * 100) / 100
                    });
                }
            }

            CircleButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰆴"
                size: Theme.px(22)
                onActivated: {
                    const id = GlobalState.gameSelected;
                    if (id === "") return;
                    GlobalState.gameSelected = "";
                    Config.removeGameWidget(id);
                }
            }
        }
    }

    // ── Rail ──────────────────────────────────────────────────────────
    NCard {
        id: rail
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(22)
        radius: Theme.r.pill
        implicitWidth: Math.min(parent.width - Theme.px(32),
                                railRow.implicitWidth + Theme.px(20))
        implicitHeight: Theme.px(64)
        opacity: win.editing ? 1 : 0
        visible: win.editing || opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        Row {
            id: railRow
            anchors.centerIn: parent
            spacing: Theme.px(4)

            // Game mode
            Item {
                width: Theme.px(52)
                height: Theme.px(52)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r.chip
                    color: Config.gameMode
                        ? Theme.c.red
                        : (gameMa.containsMouse ? Theme.c.surface2 : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.med } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.px(4)

                    NIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰊴"
                        size: Theme.z.iconL
                    }
                    NLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Game"
                        dim: !Config.gameMode
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.px(4)
                    spacing: Theme.px(3)
                    visible: Config.gameMode
                    Repeater {
                        model: [
                            Config.gameNoAnimations,
                            Config.gameNoBlur,
                            Config.gameNoShadow,
                            Config.gameTearing
                        ]
                        Rectangle {
                            required property bool modelData
                            width: Theme.px(3); height: width; radius: width / 2
                            color: modelData ? Theme.c.on : Theme.veil(0.25)
                        }
                    }
                }

                MouseArea {
                    id: gameMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Game.toggle()
                    onPressAndHold: GlobalState.settingsOpen = true
                }

                Tooltip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: Theme.px(8)
                    text: Config.gameMode
                        ? "Game mode on - hold for settings"
                        : "Game mode off - hold for settings"
                    shown: gameMa.containsMouse
                }
            }

            // Crosshair, with live preview
            Item {
                width: Theme.px(52)
                height: Theme.px(52)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r.chip
                    color: Config.crosshair
                        ? Theme.c.surface3
                        : (aimMa.containsMouse ? Theme.c.surface2 : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                CrosshairArt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.px(6)
                    scale: 0.45
                    opacity: Config.crosshair ? 1 : 0.4
                }

                NLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.px(6)
                    text: "Aim"
                    dim: !Config.crosshair
                }

                MouseArea {
                    id: aimMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) win.cycleCrosshair();
                        else {
                            Config.crosshair = !Config.crosshair;
                            Config.save();
                        }
                    }
                }

                Tooltip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: Theme.px(8)
                    text: "Left: toggle  ·  Right: next shape"
                    shown: aimMa.containsMouse
                }
            }

            GRailButton {
                icon: "󰖯"
                label: "Hud"
                tip: "Hide bar and dock while game mode is on"
                active: Config.gameHideShell
                onActivated: {
                    Config.gameHideShell = !Config.gameHideShell;
                    Config.save();
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: Theme.px(28)
                color: Theme.c.outline
            }

            Repeater {
                model: GameRegistry.all

                GRailButton {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.short
                    tip: modelData.label + " - " + modelData.hint
                    active: Config.gameWidgetEnabled(modelData.id)
                    marked: Config.gameWidget(modelData.id)?.pinned ?? false
                    onActivated: win.place(modelData.id)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: Theme.px(28)
                color: Theme.c.outline
            }

            GRailButton {
                icon: "󰓛"
                label: "Stop"
                tip: "Stop recording"
                active: true
                danger: true
                visible: Recorder.recording
                onActivated: Recorder.stop()
            }

            SquareButton {
                icon: "󰈆"
                implicitWidth: Theme.px(40)
                implicitHeight: Theme.px(52)
                anchors.verticalCenter: parent.verticalCenter
                onActivated: GlobalState.gameBarOpen = false
            }
        }
    }

    // Stop always reachable: the bar vanishes in game mode, and the rec
    // widget is gone if the editor is closed without pinning it.
    NCard {
        id: recChip
        z: 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(18)
        radius: Theme.r.pill
        outlined: true
        border.color: Theme.c.red
        implicitWidth: recChipRow.implicitWidth + Theme.px(22)
        implicitHeight: Theme.px(32)
        visible: Recorder.recording && !win.editing

        onVisibleChanged: win.setClickable(recChip, visible)
        Component.onCompleted: win.setClickable(recChip, visible)
        Component.onDestruction: win.setClickable(recChip, false)

        Row {
            id: recChipRow
            anchors.centerIn: parent
            spacing: Theme.px(8)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(8); height: width; radius: width / 2
                color: Theme.c.red

                SequentialAnimation on opacity {
                    running: recChip.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1.0; duration: 700 }
                }
            }

            NLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop  " + Recorder.timecode()
                dim: false
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Recorder.stop()
        }
    }

    // ── Top reminder ──────────────────────────────────────────────────
    NCard {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(18)
        radius: Theme.r.pill
        implicitWidth: hintRow.implicitWidth + Theme.px(22)
        implicitHeight: Theme.px(28)
        opacity: win.editing ? 1 : 0
        visible: win.editing || opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.med } }

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: Theme.px(10)

            NLabel { text: "Drag the title"; dim: false }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: Theme.px(10); color: Theme.c.outline }
            NLabel { text: "Pin to keep in-game" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: Theme.px(10); color: Theme.c.outline }
            NLabel { text: "Esc done" }
        }
    }
}
