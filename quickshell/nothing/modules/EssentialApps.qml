import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../components/apps"
import "../services"

// Essential Apps builder. A conversation on the left of the tile,
// the live widget on the right of the header — actually stacked in the
// shelf: preview, chat, composer. Same gesture as Essential Space.
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
    readonly property bool rightSide: Config.essentialSide === "left"
    readonly property int paneW: Theme.px(400)

    property bool grabKeys: false
    property string tab: "yours"
    property string openId: ""
    property real reveal: 0
    property var draft: []
    // True until the library has been listed this opening, so a blank
    // Build screen does not hide widgets that are still loading.
    property bool landing: true

    readonly property var openSpec: {
        MiniApps.stamp;
        return win.openId === "" ? null : MiniApps.specOf(win.openId);
    }

    readonly property var thread: {
        MiniApps.stamp;
        const chat = win.openSpec?.chat ?? [];
        return chat.concat(win.draft);
    }

    visible: want || reveal > 0.02
    mask: Region { item: win.want ? catcher : shelf }

    function showLibrary(): void {
        win.openId = "";
        win.draft = [];
        win.tab = MiniApps.empty ? "build" : "yours";
        win.landing = false;
    }

    function land(): void {
        if (!win.want || MiniApps.busy)
            return;
        const focus = GlobalState.appsFocus;
        if (focus !== "") {
            MiniApps.lastId = focus;
            win.openId = focus;
            win.tab = "build";
            GlobalState.appsFocus = "";
            win.landing = false;
            return;
        }
        // Always land on the library when anything exists. Restoring the
        // last conversation looked like an empty Build and hid the rest.
        if (!MiniApps.empty) {
            win.tab = "yours";
            win.openId = "";
            win.landing = false;
            return;
        }
        win.tab = "build";
        win.openId = "";
        // Keep landing: the list may still be in flight.
    }

    onWantChanged: {
        if (want) {
            grabKeys = true;
            reveal = 1;
            win.landing = true;
            MiniApps.refresh();
            win.land();
            Qt.callLater(() => ask.takeFocus());
        } else {
            if (win.openId !== "")
                MiniApps.lastId = win.openId;
            grabKeys = false;
            reveal = 0;
            win.openId = "";
            win.draft = [];
            MiniApps.lastError = "";
            MiniApps.note = "";
        }
    }

    Timer {
        interval: 80
        running: win.want && win.grabKeys && !ask.focused
        onTriggered: win.grabKeys = false
    }

    Connections {
        target: MiniApps
        function onStampChanged(): void {
            const id = MiniApps.awaiting;
            if (id !== "") {
                MiniApps.awaiting = "";
                MiniApps.lastId = id;
                win.draft = [];
                if (win.want) {
                    win.openId = id;
                    win.tab = "build";
                    win.landing = false;
                    ask.clear();
                }
                return;
            }
            if (win.want && win.landing)
                win.land();
        }
    }

    function send(text: string): void {
        const value = (text ?? "").trim();
        if (value === "" || MiniApps.busy)
            return;
        win.draft = win.draft.concat([{ role: "user", text: value }]);
        win.tab = "build";
        win.landing = false;
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
                    win.showLibrary();
                    return;
                }
                GlobalState.appsOpen = false;
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

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
                        onActivated: win.showLibrary()
                    }

                    DisplayText {
                        text: win.openId !== ""
                            ? (win.openSpec?.name ?? "WIDGET").toUpperCase()
                            : "ESSENTIAL APPS"
                        size: Theme.px(18)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    NLabel {
                        text: MiniApps.specs.length + " BUILT"
                        dim: false
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.showLibrary()
                        }
                    }
                }

                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    visible: win.openId === ""
                    current: win.tab
                    options: [
                        { label: "Yours", value: "yours" },
                        { label: "Build", value: "build" },
                        { label: "Presets", value: "presets" }
                    ]
                    onPicked: (v) => {
                        win.landing = false;
                        if (v === "build")
                            win.openId = "";
                        win.tab = v;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // ── Builder ──────────────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        visible: (win.tab === "build" && win.openId === "") || win.openId !== ""
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: preview.implicitHeight + Theme.px(24)
                            visible: win.openSpec !== null

                            AppHost {
                                id: preview
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spec: win.openSpec ?? ({ name: "", size: "s", face: "stat" })
                                chrome: false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.pad
                            Layout.rightMargin: Theme.pad
                            Layout.bottomMargin: Theme.px(8)
                            visible: win.openId !== ""
                            spacing: Theme.px(6)

                            NPillButton {
                                text: Config.hasDeskApp(win.openId) ? "ON DESKTOP" : "ADD TO DESKTOP"
                                onActivated: Config.toggleDeskApp(win.openId)
                            }
                            Item { Layout.fillWidth: true }
                            CircleButton {
                                icon: "󰦛"
                                size: Theme.px(24)
                                onActivated: MiniApps.reset(win.openId)
                            }
                            CircleButton {
                                icon: "󰩹"
                                size: Theme.px(24)
                                onActivated: {
                                    MiniApps.remove(win.openId);
                                    win.showLibrary();
                                }
                            }
                        }

                        ListView {
                            id: chat
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: Theme.pad
                            Layout.rightMargin: Theme.pad
                            clip: true
                            spacing: Theme.px(8)
                            model: win.thread
                            boundsBehavior: Flickable.StopAtBounds

                            onCountChanged: Qt.callLater(() =>
                                chat.positionViewAtEnd())

                            delegate: Rectangle {
                                required property var modelData
                                width: chat.width
                                implicitHeight: bubble.implicitHeight + Theme.px(12)
                                color: "transparent"

                                readonly property bool mine: modelData.role === "user"

                                Rectangle {
                                    id: bubble
                                    anchors.left: parent.mine ? undefined : parent.left
                                    anchors.right: parent.mine ? parent.right : undefined
                                    width: Math.min(parent.width * 0.86,
                                        talk.implicitWidth + Theme.px(20))
                                    implicitHeight: talk.implicitHeight + Theme.px(12)
                                    radius: Theme.r.tiny
                                    color: parent.mine ? Theme.c.surface3 : Theme.c.surface2

                                    NText {
                                        id: talk
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: Theme.px(10)
                                        text: modelData.text ?? ""
                                        wrapMode: Text.WordWrap
                                        color: Theme.c.on
                                    }
                                }
                            }

                            // Empty builder
                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chat.count === 0 && win.openId === "" && !MiniApps.busy
                                spacing: Theme.px(10)

                                DisplayText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "DESCRIBE IT"
                                    size: Theme.px(18)
                                    color: Theme.c.onFaint
                                }
                                NText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "A widget for the desktop. One job. Then pin it."
                                    color: Theme.c.onDim
                                    wrapMode: Text.WordWrap
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.topMargin: Theme.px(6)
                                    spacing: Theme.px(6)

                                    Repeater {
                                        model: [
                                            "Cups of water today, goal 8",
                                            "Countdown to Friday 18:00",
                                            "Next F1 race",
                                            "What 1 euro buys in USD"
                                        ]
                                        Rectangle {
                                            required property string modelData
                                            implicitWidth: chipLab.implicitWidth + Theme.px(16)
                                            implicitHeight: Theme.px(24)
                                            radius: height / 2
                                            color: Theme.c.surface2
                                            NText {
                                                id: chipLab
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: Theme.f.tiny
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ask.text = modelData;
                                                    ask.takeFocus();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    AppsGallery {
                        anchors.fill: parent
                        visible: win.tab === "yours" && win.openId === ""
                        onOpened: (id) => { win.openId = id; win.tab = "build"; }
                    }

                    AppsPresets {
                        anchors.fill: parent
                        visible: win.tab === "presets" && win.openId === ""
                        onSeeded: (text) => {
                            win.tab = "build";
                            ask.text = text;
                            ask.takeFocus();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(8)
                    visible: MiniApps.busy || MiniApps.lastError !== ""
                        || MiniApps.note !== ""
                    spacing: Theme.px(8)

                    Rectangle {
                        width: Theme.px(5); height: width; radius: width / 2
                        color: MiniApps.lastError !== "" ? Theme.c.red : Theme.c.onDim
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
                            ? MiniApps.status + " · Esc to stop"
                            : (MiniApps.lastError !== "" ? MiniApps.lastError
                                                         : MiniApps.note)
                        color: MiniApps.lastError !== "" ? Theme.c.red : Theme.c.onDim
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.pad
                    implicitHeight: Theme.px(38)
                    radius: Theme.r.pill
                    color: Theme.c.surface2
                    border.width: 1
                    border.color: ask.focused ? Theme.c.red : Theme.c.outline

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
                                ? "A water tracker, a race countdown…"
                                : "Make the number red, add a goal…"
                            onSubmitted: (v) => win.send(v)
                            onFocusedChanged: if (focused) win.grabKeys = true
                        }

                        Rectangle {
                            Layout.preferredWidth: Theme.px(28)
                            Layout.preferredHeight: Theme.px(28)
                            radius: width / 2
                            color: MiniApps.busy
                                ? Theme.c.red
                                : (goMa.containsMouse ? Theme.c.red : Theme.c.surface3)

                            NIcon {
                                anchors.centerIn: parent
                                text: MiniApps.busy ? "󰓛" : "󰁔"
                                size: Theme.px(13)
                                color: Theme.c.on
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
            }
        }
    }
}
