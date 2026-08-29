import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../components/apps"
import "../services"

// Essential Apps as a side shelf, the same gesture as Essential Space.
// It opens on the opposite edge, which mirrors the bar: the dot grid sits
// left of the clock and the Essential Key sits right of it.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-apps-panel"
    WlrLayershell.keyboardFocus: (win.want && win.grabKeys)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.z.barWin
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    readonly property bool want: GlobalState.appsOpen && win.onFocusedMonitor
    // Opposite edge to the vault: the two shelves never share a side.
    readonly property bool rightSide: Config.essentialSide === "left"
    readonly property int paneW: Theme.px(392)

    property bool grabKeys: false
    property string tab: "yours"
    property string openId: ""
    property real reveal: 0

    readonly property var openSpec: {
        MiniApps.stamp;
        return win.openId === "" ? null : MiniApps.specOf(win.openId);
    }

    visible: want || reveal > 0.02
    mask: Region { item: win.want ? catcher : shelf }

    onWantChanged: {
        if (want) {
            grabKeys = true;
            reveal = 1;
            MiniApps.refresh();
            const focus = GlobalState.appsFocus;
            if (focus !== "") {
                win.openId = focus;
                GlobalState.appsFocus = "";
            }
            Qt.callLater(() => { if (win.openId === "") ask.takeFocus(); });
        } else {
            grabKeys = false;
            reveal = 0;
            win.openId = "";
            MiniApps.lastError = "";
            MiniApps.note = "";
        }
    }

    // Clicking a window blurs the composer: drop the grab so typing goes
    // back to that window, and take it again on the next click inside.
    Timer {
        interval: 80
        running: win.want && win.grabKeys && !ask.focused
        onTriggered: win.grabKeys = false
    }

    Connections {
        target: MiniApps
        function onStampChanged(): void {
            const id = MiniApps.awaiting;
            if (id === "" || !win.want)
                return;
            MiniApps.awaiting = "";
            win.openId = id;
            win.tab = "yours";
            ask.clear();
        }
    }

    function send(text: string): void {
        const value = (text ?? "").trim();
        if (value === "" || MiniApps.busy)
            return;
        if (win.openId === "")
            MiniApps.create(value);
        else
            MiniApps.refine(win.openId, value);
        ask.clear();
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        enabled: win.want
        onPressed: GlobalState.appsOpen = false
    }

    Rectangle {
        id: shelf
        width: win.paneW
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(8)
        // x rather than left+right anchors: pinning both edges made the
        // pane eat the screen when the side flipped.
        x: win.rightSide ? parent.width - width : 0
        color: Theme.c.surface
        radius: Theme.px(4)
        clip: true

        transform: Translate {
            x: win.rightSide
                ? shelf.width * (1 - win.reveal)
                : -shelf.width * (1 - win.reveal)
            Behavior on x {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
        }
        opacity: win.reveal > 0.04 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.med; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: (m) => { win.grabKeys = true; m.accepted = true; }
        }

        FocusScope {
            anchors.fill: parent
            focus: win.want
            Keys.onEscapePressed: {
                if (MiniApps.busy) {
                    MiniApps.cancel();
                    return;
                }
                if (win.openId !== "") {
                    win.openId = "";
                    return;
                }
                GlobalState.appsOpen = false;
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Header ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.topMargin: Theme.px(18)
                    Layout.bottomMargin: Theme.px(12)
                    spacing: Theme.px(10)

                    CircleButton {
                        icon: "󰁍"
                        size: Theme.px(24)
                        visible: win.openId !== ""
                        onActivated: win.openId = ""
                    }

                    DisplayText {
                        text: win.openId !== ""
                            ? (win.openSpec?.name ?? "APP").toUpperCase()
                            : "ESSENTIAL APPS"
                        size: Theme.px(18)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    NLabel {
                        text: win.openId !== ""
                            ? "V" + (win.openSpec?.version ?? 1)
                            : MiniApps.specs.length + " BUILT"
                        dim: false
                    }
                }

                // ── Composer ─────────────────────────────────────────
                // One field for both jobs: it writes a new app, or asks
                // for a change to the one that is open.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    implicitHeight: Theme.px(38)
                    radius: Theme.r.pill
                    color: Theme.c.surface2
                    border.width: 1
                    border.color: ask.focused ? Theme.c.red : Theme.c.outline
                    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(14)
                        anchors.rightMargin: Theme.px(5)
                        spacing: Theme.px(9)

                        NIcon {
                            text: win.openId === "" ? "󰧑" : "󰏫"
                            size: Theme.z.icon
                            color: ask.focused ? Theme.c.red : Theme.c.onFaint
                        }

                        NField {
                            id: ask
                            Layout.fillWidth: true
                            implicitWidth: 0
                            implicitHeight: Theme.px(32)
                            color: "transparent"
                            border.width: 0
                            enabled: !MiniApps.busy
                            placeholder: win.openId === ""
                                ? "Describe an app"
                                : "Describe a change"
                            onSubmitted: (v) => win.send(v)
                            onFocusedChanged: if (focused) win.grabKeys = true
                        }

                        // Send, and stop while it is working. A prompt
                        // can be wrong the moment it leaves, and a
                        // generation runs for the better part of a minute.
                        Rectangle {
                            Layout.preferredWidth: Theme.px(28)
                            Layout.preferredHeight: Theme.px(28)
                            radius: width / 2
                            color: MiniApps.busy
                                ? Theme.c.red
                                : (goMa.containsMouse ? Theme.c.red : Theme.c.surface3)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            NIcon {
                                anchors.centerIn: parent
                                text: MiniApps.busy ? "󰓛" : "󰁔"
                                size: MiniApps.busy ? Theme.px(12) : Theme.px(13)
                                color: Theme.c.on
                            }

                            // The ring breathes while it works, so the
                            // button reads as busy without hiding the
                            // stop it now offers.
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + Theme.px(6)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.c.red
                                visible: MiniApps.busy

                                SequentialAnimation on opacity {
                                    running: MiniApps.busy
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.15; duration: 700 }
                                    NumberAnimation { to: 0.9; duration: 700 }
                                }
                            }

                            MouseArea {
                                id: goMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (MiniApps.busy)
                                        MiniApps.cancel();
                                    else
                                        win.send(ask.text);
                                }
                            }
                        }
                    }
                }

                // ── Status ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(8)
                    visible: MiniApps.busy || MiniApps.lastError !== ""
                        || MiniApps.note !== ""
                    spacing: Theme.px(8)

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Theme.px(4)
                        width: Theme.px(5); height: width; radius: width / 2
                        color: MiniApps.lastError !== "" ? Theme.c.red
                             : (MiniApps.busy ? Theme.c.red : Theme.c.onDim)
                        SequentialAnimation on opacity {
                            running: MiniApps.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 620 }
                            NumberAnimation { to: 1; duration: 620 }
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: MiniApps.busy
                            ? MiniApps.status + " · Esc or the square to stop"
                            : (MiniApps.lastError !== "" ? MiniApps.lastError
                                                         : MiniApps.note)
                        color: MiniApps.lastError !== "" ? Theme.c.red : Theme.c.onDim
                        wrapMode: Text.WordWrap
                    }
                }

                // ── Tabs ─────────────────────────────────────────────
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    visible: win.openId === ""
                    current: win.tab
                    options: [
                        { label: "Yours", value: "yours" },
                        { label: "Presets", value: "presets" }
                    ]
                    onPicked: (v) => win.tab = v
                }

                // ── Content ──────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    AppsGallery {
                        anchors.fill: parent
                        visible: win.openId === "" && win.tab === "yours"
                        onOpened: (id) => win.openId = id
                    }

                    AppsPresets {
                        anchors.fill: parent
                        visible: win.openId === "" && win.tab === "presets"
                        onSeeded: (text) => { ask.text = text; ask.takeFocus(); }
                    }

                    AppsDetail {
                        anchors.fill: parent
                        visible: win.openId !== ""
                        spec: win.openSpec
                        onClosed: win.openId = ""
                    }
                }
            }
        }
    }
}
