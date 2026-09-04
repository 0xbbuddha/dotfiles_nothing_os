import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// App launcher: fuzzy search, keyboard navigation.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    // Shown only on the focused monitor.
    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    color: "transparent"
    visible: GlobalState.launcherOpen && onFocusedMonitor
        && !Shot.picking && !Recorder.picking
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-launcher"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    readonly property var results: Search.results
    property int selected: 0

    onVisibleChanged: {
        if (visible) {
            Hyprland.refreshToplevels();
            Essentials.refresh();
            Essentials.probeKey();
            // A query may be imposed by the shortcut that opened the panel
            // (SUPER+V for the clipboard, for example).
            win.applyQuery();
        } else {
            Search.clearAsk();
        }
    }

    // Apply the imposed query. Needed in addition to onVisibleChanged:
    // if the panel is already open, switching mode does not change its
    // visibility and the field would keep the old prefix.
    function applyQuery(): void {
        if (GlobalState.launcherQuery.startsWith(";"))
            Clipboard.refresh();
        search.text = GlobalState.launcherQuery;
        search.cursorPosition = search.text.length;
        win.refresh();
        search.forceActiveFocus();
    }

    Connections {
        target: GlobalState
        function onLauncherQueryChanged(): void {
            if (win.visible) win.applyQuery();
        }
    }

    function refresh(): void {
        Search.query = search.text;
        win.selected = 0;
    }


    function launch(index: int): void {
        const r = win.results[index];
        if (!r) return;
        r.run();
        // Clipboard and emoji modes stay open so you can chain actions.
        if (r.kind !== "emoji" && r.kind !== "clip")
            GlobalState.launcherOpen = false;
    }

    function move(delta: int): void {
        if (win.results.length === 0) return;
        win.selected = (win.selected + delta + win.results.length) % win.results.length;
        list.positionViewAtIndex(win.selected, ListView.Contain);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: GlobalState.launcherOpen = false }
    }

    // The sheet widens to host the grid when nothing is typed,
    // and tightens onto results as soon as you search.
    readonly property bool browsing: search.text === ""

    NCard {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        width: win.browsing
            ? Math.max(Theme.px(460), grid.implicitWidth + Theme.px(40))
            : Theme.px(460)
        height: win.browsing
            ? (Theme.px(74) + grid.implicitHeight + Theme.px(24))
            : Math.min(Theme.px(480), parent.height * 0.62)
        clip: true

        Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
        Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        scale: win.visible ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Search bar ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.pad
                spacing: Theme.px(9)

                NIcon { text: "󰍉"; size: Theme.z.iconM; color: Theme.c.onDim }

                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.big
                    selectByMouse: true
                    selectionColor: Theme.c.red
                    focus: true

                    onTextChanged: win.refresh()

                    Keys.onEscapePressed: GlobalState.launcherOpen = false
                    Keys.onDownPressed: win.move(1)
                    Keys.onUpPressed: win.move(-1)
                    Keys.onReturnPressed: (event) => {
                        if (event.modifiers & Qt.ControlModifier) {
                            Search.askNow(search.text);
                            event.accepted = true;
                            return;
                        }
                        win.launch(win.selected);
                    }
                    Keys.onEnterPressed: (event) => {
                        if (event.modifiers & Qt.ControlModifier) {
                            Search.askNow(search.text);
                            event.accepted = true;
                            return;
                        }
                        win.launch(win.selected);
                    }
                    Keys.onTabPressed: win.move(1)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Essential Search"
                        color: Theme.c.onFaint
                        font: search.font
                    }
                }

                // Active-mode chip, when a prefix is in use
                Rectangle {
                    visible: Search.modeLabel(search.text) !== ""
                    implicitWidth: modeLabel.implicitWidth + Theme.px(14)
                    implicitHeight: Theme.px(20)
                    radius: height / 2
                    color: Theme.c.red

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: Search.modeLabel(search.text)
                        color: Theme.c.onAccent
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.micro
                        font.letterSpacing: Theme.f.track
                        font.capitalization: Font.AllUppercase
                    }
                }

                // Ask — Gemini, in place. Red, not yellow: the accent
                // is already the Nothing red of this shell.
                Rectangle {
                    visible: Search.askReady(search.text)
                    implicitWidth: askLab.implicitWidth + Theme.px(16)
                    implicitHeight: Theme.px(20)
                    radius: height / 2
                    color: Theme.c.red
                    opacity: Search.askBusy ? 0.55 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                    Text {
                        id: askLab
                        anchors.centerIn: parent
                        text: Search.askBusy ? "…" : "Ask"
                        color: Theme.c.onAccent
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.micro
                        font.letterSpacing: Theme.f.track
                        font.capitalization: Font.AllUppercase
                    }

                    MouseArea {
                        id: askMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Search.askBusy
                        onClicked: Search.askNow(search.text)
                    }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: Theme.px(6)
                        text: "Ask Gemini · Ctrl+Enter"
                        shown: askMa.containsMouse
                        z: 50
                    }
                }

                NLabel {
                    text: win.browsing
                        ? Config.workspaceCount + " workspaces"
                        : win.results.length + " results"
                }

                // ── Google Lens ──────────────────────────────────────
                Rectangle {
                    implicitWidth: Theme.px(30)
                    implicitHeight: Theme.px(30)
                    radius: width / 2
                    color: lensMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                    opacity: Lens.busy ? 0.5 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    NIcon {
                        anchors.centerIn: parent
                        text: "󰈃"
                        size: Theme.z.iconM
                        color: Theme.c.onDim
                    }

                    MouseArea {
                        id: lensMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            GlobalState.launcherOpen = false;
                            Lens.search();
                        }
                    }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: Theme.px(6)
                        text: "Google Lens · the selection is uploaded to a third party"
                        shown: lensMa.containsMouse
                        z: 50
                    }
                }

                // ── Music recognition ─────────────────────────────────
                Rectangle {
                    id: songBtn
                    implicitWidth: Theme.px(30)
                    implicitHeight: Theme.px(30)
                    radius: width / 2
                    color: Songrec.listening ? Theme.c.red
                         : (songMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                    opacity: Songrec.available ? 1 : 0.35
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    NIcon {
                        anchors.centerIn: parent
                        text: Songrec.listening ? "󰎇" : "󰎈"
                        size: Theme.z.iconM
                        color: Songrec.listening ? Theme.c.on : Theme.c.onDim
                    }

                    // Ring that pulses while listening
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.c.red
                        visible: Songrec.listening

                        SequentialAnimation on scale {
                            running: Songrec.listening
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.5; duration: 1100 }
                        }
                        SequentialAnimation on opacity {
                            running: Songrec.listening
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.8; to: 0; duration: 1100 }
                        }
                    }

                    MouseArea {
                        id: songMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Songrec.available
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Songrec.toggle()
                    }

                    Tooltip {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: Theme.px(6)
                        text: Songrec.available
                            ? "Identify the music playing"
                            : "songrec is not installed"
                        shown: songMa.containsMouse
                        z: 50
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

            // ── Ask answer ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.pad
                Layout.rightMargin: Theme.pad
                Layout.topMargin: Theme.px(8)
                implicitHeight: askCol.implicitHeight + Theme.px(18)
                radius: Theme.r.tiny
                color: Theme.c.surface2
                visible: Search.askBusy || Search.askAnswer !== ""

                ColumnLayout {
                    id: askCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        NIcon {
                            text: "󰚩"
                            size: Theme.z.iconM
                            color: Theme.c.red
                        }

                        Text {
                            text: "Ask"
                            color: Theme.c.red
                            font.family: Theme.f.mono
                            font.pixelSize: Theme.f.micro
                            font.letterSpacing: Theme.f.track
                            font.capitalization: Font.AllUppercase
                        }

                        Item { Layout.fillWidth: true }

                        NPillButton {
                            text: "Copy"
                            visible: Search.askAnswer !== "" && !Search.askBusy
                            onActivated: Search.run(
                                `printf '%s' ${JSON.stringify(Search.askAnswer)} | wl-copy`)
                        }
                    }

                    NText {
                        Layout.fillWidth: true
                        text: Search.askBusy ? "Asking…" : Search.askAnswer
                        font.pixelSize: Theme.f.body
                        wrapMode: Text.WordWrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }
                }
            }

            // ── Results ───────────────────────────────────────────────
            // ── Music recognition feedback ────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.pad
                Layout.rightMargin: Theme.pad
                Layout.topMargin: Theme.px(8)
                implicitHeight: Theme.px(46)
                radius: Theme.r.chip
                color: Theme.c.surface2
                visible: Songrec.listening || Songrec.hasResult || Songrec.error !== ""

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(14)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(11)

                    NIcon {
                        text: Songrec.listening ? "󰎇" : (Songrec.hasResult ? "󰝚" : "󰅖")
                        size: Theme.z.iconM
                        color: Songrec.listening ? Theme.c.red : Theme.c.onDim
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        NText {
                            Layout.fillWidth: true
                            text: Songrec.listening
                                ? "Listening…"
                                : (Songrec.hasResult ? Songrec.title : Songrec.error)
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }

                        NText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: Songrec.listening
                                ? (Songrec.duration - Songrec.elapsed) + " s"
                                : Songrec.artist
                            color: Theme.c.onDim
                            elide: Text.ElideRight
                        }
                    }

                    NPillButton {
                        text: "YouTube"
                        visible: Songrec.hasResult
                        onActivated: { Songrec.openTrack(); GlobalState.launcherOpen = false; }
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(22)
                        visible: !Songrec.listening
                        onActivated: Songrec.clear()
                    }
                }
            }

            // ── Prefix reminders ──────────────────────────────────────
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.pad
                Layout.rightMargin: Theme.pad
                Layout.topMargin: Theme.px(8)
                spacing: Theme.px(6)
                visible: win.browsing

                Repeater {
                    model: Search.hints

                    Rectangle {
                        id: hint
                        required property var modelData

                        implicitWidth: hintRow.implicitWidth + Theme.px(12)
                        implicitHeight: Theme.px(20)
                        radius: Theme.r.tiny
                        color: hma.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        Row {
                            id: hintRow
                            anchors.centerIn: parent
                            spacing: Theme.px(5)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: hint.modelData.p
                                color: Theme.c.red
                                font.family: Theme.f.mono
                                font.pixelSize: Theme.f.small
                            }
                            NText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: hint.modelData.label
                                color: Theme.c.onDim
                                font.pixelSize: Theme.f.tiny
                            }
                        }

                        MouseArea {
                            id: hma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                search.text = hint.modelData.p;
                                search.cursorPosition = search.text.length;
                                search.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // ── Workspaces, when the search is empty ───────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: win.browsing ? grid.implicitHeight + Theme.px(20) : 0
                visible: win.browsing
                clip: true

                WorkspaceGrid {
                    id: grid
                    anchors.centerIn: parent
                    screenInfo: win.modelData
                    maxWidth: win.width * 0.86
                    live: win.visible && win.browsing
                    onActivated: GlobalState.launcherOpen = false
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !win.browsing
                Layout.margins: Theme.px(6)
                clip: true
                model: win.results
                spacing: Theme.px(2)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool active: win.selected === index

                    width: list.width
                    height: Theme.px(44)
                    radius: Theme.r.tiny
                    color: active ? Theme.c.surface3 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(2)
                        height: row.active ? parent.height * 0.5 : 0
                        radius: 1
                        color: Theme.c.red
                        Behavior on height { NumberAnimation { duration: Theme.fast } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        spacing: Theme.px(11)

                        // Four possible renders depending on the result kind
                        Item {
                            Layout.preferredWidth: Theme.px(24)
                            Layout.preferredHeight: Theme.px(24)

                            AppIcon {
                                anchors.centerIn: parent
                                size: Theme.px(24)
                                iconName: row.modelData.iconName ?? ""
                                visible: row.modelData.kind === "app"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.emoji ?? ""
                                font.pixelSize: Theme.px(20)
                                visible: row.modelData.kind === "emoji"
                            }

                            // Nothing's own icon where there is one, so a
                            // result for Essential Space carries the same
                            // mark here as it does in the dock.
                            NVectorIcon {
                                anchors.centerIn: parent
                                width: Theme.px(22)
                                height: Theme.px(22)
                                icon: row.modelData.vector ?? ""
                                color: Theme.c.onDim
                                visible: (row.modelData.vector ?? "") !== ""
                            }

                            NIcon {
                                anchors.centerIn: parent
                                text: row.modelData.icon ?? ""
                                size: Theme.z.iconL
                                color: row.modelData.kind === "math" ? Theme.c.red : Theme.c.onDim
                                visible: row.modelData.kind !== "app"
                                       && row.modelData.kind !== "emoji"
                                       && (row.modelData.vector ?? "") === ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                color: Theme.c.on
                                font.family: row.modelData.kind === "math"
                                    || row.modelData.kind === "shell"
                                    ? Theme.f.mono : Theme.f.sans
                                font.pixelSize: Theme.f.body
                                elide: Text.ElideRight
                            }

                            NText {
                                Layout.fillWidth: true
                                text: row.modelData.subtitle ?? ""
                                visible: text !== ""
                                color: Theme.c.onDim
                                elide: Text.ElideRight
                            }
                        }

                        NIcon {
                            text: "󰌑"
                            size: Theme.z.icon
                            color: Theme.c.onFaint
                            visible: row.active
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.selected = row.index
                        onClicked: win.launch(row.index)
                    }
                }
            }

            NText {
                Layout.fillWidth: true
                Layout.margins: Theme.pad
                visible: win.results.length === 0 && !win.browsing
                    && !Search.askBusy && Search.askAnswer === ""
                text: "No matching results."
                color: Theme.c.onDim
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

}
