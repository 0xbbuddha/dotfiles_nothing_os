import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Essential Space as a side shelf: For You / Library, dump at the bottom.
// A transparent catcher covers the rest of the screen (not the bar) so a
// click outside closes it. Ndot is reserved for the title.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-essential"
    // OnDemand, never Exclusive: Exclusive ate the bar button.
    WlrLayershell.keyboardFocus: (win.want && (win.grabKeys || dump.focused || find.focused)
            && !win.catching)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.z.barWin
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")
    readonly property bool want:
        GlobalState.essentialOpen && Config.essentialEnabled && onFocusedMonitor
    readonly property bool rightSide: Config.essentialSide !== "left"
    readonly property int paneW: Theme.px(372)

    property bool grabKeys: false
    property bool searching: false
    property string tab: "lib"
    property string openedId: ""
    property real reveal: 0

    readonly property bool catching:
        GlobalState.essentialCatching && Config.essentialEnabled
        && (GlobalState.essentialFlyScreen === (win.modelData?.name ?? "")
            || GlobalState.essentialFlyScreen === "")

    readonly property var detailItem: {
        Essentials.stamp;
        const id = win.openedId;
        if (id === "")
            return null;
        const src = Essentials.items;
        for (let i = 0; i < src.length; i++) {
            if (src[i].id === id)
                return src[i];
        }
        return null;
    }

    // Never keep an invisible fullscreen overlay mapped: it sits above
    // the notification centre and eats its open animation.
    visible: want || catching || reveal > 0.02

    // While the shelf is open the catcher is the input region so a click
    // outside closes it. While peeking, only the shelf is live — the rest
    // of the screen (and the bar above this window) stays clickable.
    mask: Region { item: (win.want && !win.catching) ? catcher : shelf }

    onWantChanged: {
        if (want) {
            grabKeys = true;
            reveal = 1;
            Essentials.refresh();
            dump.clear();
            Qt.callLater(() => dump.takeFocus());
            if (win.searching)
                Qt.callLater(() => find.takeFocus());
            Essentials.endPeek();
        } else {
            grabKeys = false;
            if (!win.catching)
                reveal = 0;
        }
    }

    onCatchingChanged: {
        if (catching) {
            tab = "lib";
            openedId = "";
            reveal = 0;
            Qt.callLater(() => {
                if (win.catching)
                    win.reveal = 0.8;
            });
        } else if (!want) {
            reveal = 0;
        }
    }

    // Clicking a window blurs the dump field: drop the keyboard grab so
    // typing goes back to that window. Clicking the pane again restores it.
    Timer {
        id: releaseKeys
        interval: 80
        running: win.want && win.grabKeys && !dump.focused && !find.focused
        onTriggered: win.grabKeys = false
    }

    function dumpNow(): void {
        Essentials.addNote(dump.text);
        dump.clear();
        dump.takeFocus();
    }

    function kindIcon(kind: string): string {
        switch (kind) {
        case "snip": return "󰄀";
        case "ocr": return "󰈚";
        case "clip": return "󰅌";
        case "record": return "󰑊";
        case "voice": return "󰍬";
        case "song": return "󰎈";
        case "calc": return "󰃬";
        default: return "󰠮";
        }
    }

    function when(at: string): string {
        return (at ?? "").replace("T", " ").slice(0, 16);
    }

    function matches(it: var): bool {
        const q = find.text.trim().toLowerCase();
        if (q === "")
            return true;
        const blob = [it.title, it.summary, it.text, it.kind].join(" ").toLowerCase();
        return blob.indexOf(q) >= 0;
    }

    function forYou(it: var): bool {
        // An explicit hide always wins: actions/reminders must not pull
        // the card back into For You after "Not For You".
        if (it.forYou === false || it.forYou === "false")
            return false;
        if (it.forYou === true || it.forYou === "true")
            return true;
        const w = (it.when ?? "").trim();
        if (w !== "" && w.toLowerCase() !== "null")
            return true;
        const rem = it.reminders ?? [];
        if (rem.length > 0)
            return true;
        const acts = it.actions ?? [];
        const kind = it.kind ?? "";
        if ((kind === "voice" || kind === "note") && acts.length > 0)
            return true;
        return false;
    }

    function whenPretty(iso: string): string {
        const raw = (iso ?? "").trim();
        if (raw === "")
            return "";
        const d = new Date(raw);
        if (isNaN(d.getTime()))
            return raw.replace("T", " ").slice(0, 16);
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        const dd = d.getDate();
        const hh = d.getHours();
        const mm = d.getMinutes();
        const h = hh < 10 ? "0" + hh : "" + hh;
        const m = mm < 10 ? "0" + mm : "" + mm;
        return dd + " " + months[d.getMonth()] + "  " + h + ":" + m;
    }

    function atLong(iso: string): string {
        const raw = (iso ?? "").trim();
        if (raw === "")
            return "";
        const d = new Date(raw);
        if (isNaN(d.getTime()))
            return raw.replace("T", " ").slice(0, 19);
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        const dd = d.getDate();
        const hh = d.getHours();
        const mm = d.getMinutes();
        const ss = d.getSeconds();
        const h = hh < 10 ? "0" + hh : "" + hh;
        const m = mm < 10 ? "0" + mm : "" + mm;
        const s = ss < 10 ? "0" + ss : "" + ss;
        return dd + " " + months[d.getMonth()] + " " + d.getFullYear()
            + "  ·  " + h + ":" + m + ":" + s;
    }

    function pad2(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function isoLocal(d: var): string {
        return d.getFullYear() + "-" + win.pad2(d.getMonth() + 1)
            + "-" + win.pad2(d.getDate()) + "T" + win.pad2(d.getHours())
            + ":" + win.pad2(d.getMinutes()) + ":" + win.pad2(d.getSeconds());
    }

    function tomorrowNine(): string {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        d.setHours(9, 0, 0, 0);
        return win.isoLocal(d);
    }

    function plusHour(): string {
        return win.isoLocal(new Date(Date.now() + 3600 * 1000));
    }

    function isAudio(p: string): bool {
        return /\.(oga|ogg|opus|wav|mp3|m4a|flac)$/i.test(p ?? "");
    }

    readonly property var shownItems: {
        Essentials.stamp;
        find.text;
        win.searching;
        win.tab;
        const src = Essentials.items;
        const out = [];
        for (let i = 0; i < src.length; i++) {
            const it = src[i];
            if (win.tab === "you" && !win.forYou(it))
                continue;
            if (win.tab === "lib" && win.searching && !win.matches(it))
                continue;
            out.push(it);
        }
        if (win.tab === "you")
            out.sort((a, b) => String(a.when ?? "").localeCompare(String(b.when ?? "")));
        return out;
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        enabled: win.want && !win.catching
        onPressed: GlobalState.essentialOpen = false
    }

    Rectangle {
        id: shelf
        width: win.paneW
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(8)
        anchors.left: win.rightSide ? undefined : parent.left
        anchors.right: win.rightSide ? parent.right : undefined
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
            onPressed: (m) => {
                win.grabKeys = true;
                m.accepted = true;
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: win.want
            Keys.onEscapePressed: {
                if (win.openedId !== "") {
                    win.openedId = "";
                    return;
                }
                if (win.searching) {
                    win.searching = false;
                    return;
                }
                GlobalState.essentialOpen = false;
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.topMargin: Theme.px(18)
                    Layout.bottomMargin: Theme.px(6)
                    spacing: Theme.px(10)

                    DisplayText { text: "ESSENTIAL"; size: Theme.px(18) }

                    Item { Layout.fillWidth: true }

                    NLabel {
                        visible: Essentials.busy || Songrec.listening
                            || Recorder.recording || Voice.recording
                        text: Voice.recording ? ("VOICE  " + Voice.timecode())
                            : (Recorder.recording ? Recorder.timecode()
                            : (Songrec.listening ? "LISTENING"
                            : (Essentials.busy ? "MIND" : "")))
                        dim: false
                    }
                }

                NField {
                    id: find
                    visible: win.searching
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.pad
                    Layout.rightMargin: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    placeholder: "Search the vault"
                    onEscaped: {
                        win.searching = false;
                        find.clear();
                    }
                    onFocusedChanged: if (focused) win.grabKeys = true
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        visible: win.detailItem === null
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: Theme.px(10)
                        topMargin: Theme.px(2)
                        bottomMargin: Theme.pad
                        leftMargin: Theme.pad
                        rightMargin: Theme.pad
                        model: win.shownItems

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            width: list.width - Theme.pad * 2
                            implicitHeight: Math.max(Theme.px(76), compact.implicitHeight + Theme.px(16))
                            radius: Theme.r.chip
                            color: cardMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                            clip: true

                            readonly property var it: card.modelData
                            readonly property bool hasImage: {
                                const p = card.it?.path ?? "";
                                return /\.(png|jpe?g|webp)$/i.test(p);
                            }
                            readonly property bool pending: card.it.mind === "pending"

                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Theme.px(2)
                                color: Theme.c.red
                            }

                            RowLayout {
                                id: compact
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.px(14)
                                anchors.rightMargin: Theme.px(12)
                                spacing: Theme.px(12)

                                Image {
                                    Layout.preferredWidth: Theme.px(64)
                                    Layout.preferredHeight: Theme.px(64)
                                    visible: card.hasImage && win.tab !== "you"
                                    source: card.hasImage ? ("file://" + card.it.path) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.height: Theme.px(64)
                                }

                                Rectangle {
                                    Layout.preferredWidth: Theme.px(36)
                                    Layout.preferredHeight: Theme.px(36)
                                    visible: !card.hasImage && ["voice", "record", "song"]
                                        .indexOf(card.it.kind ?? "") >= 0
                                    radius: Theme.r.tiny
                                    color: Theme.c.surface

                                    NIcon {
                                        anchors.centerIn: parent
                                        text: win.kindIcon(card.it.kind ?? "note")
                                        size: Theme.px(16)
                                        color: Theme.c.onDim
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(3)

                                    Text {
                                        Layout.fillWidth: true
                                        visible: win.tab === "you" && (card.it.when ?? "") !== ""
                                        text: win.whenPretty(card.it.when ?? "")
                                        color: Theme.c.on
                                        font.family: Theme.f.display
                                        font.pixelSize: Theme.px(16)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: card.pending
                                            ? "Mind…"
                                            : ((card.it.title ?? "") !== ""
                                                ? card.it.title
                                                : (card.it.kind ?? "note"))
                                        color: Theme.c.on
                                        font.family: Theme.f.sans
                                        font.pixelSize: Theme.f.body
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        opacity: card.pending ? 0.4 : 1
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 520
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: win.tab !== "you"
                                            && !card.pending
                                            && (card.it.summary ?? "") !== ""
                                            && card.it.summary !== card.it.title
                                        text: card.it.summary
                                        color: card.it.mind === "error" || card.it.mind === "nokey"
                                            ? Theme.c.red : Theme.c.onDim
                                        font.family: Theme.f.sans
                                        font.pixelSize: Theme.f.small
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: win.atLong(card.it.at ?? "")
                                        color: Theme.c.onFaint
                                        font.family: Theme.f.mono
                                        font.pixelSize: Theme.f.micro
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openedId = card.it.id ?? ""
                            }
                        }
                    }

                    Flickable {
                        id: detail
                        anchors.fill: parent
                        visible: win.detailItem !== null
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: detailCol.implicitHeight + Theme.pad * 2

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.c.surface
                        }

                        ColumnLayout {
                            id: detailCol
                            width: detail.width - Theme.pad * 2
                            x: Theme.pad
                            y: Theme.pad
                            spacing: Theme.px(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(8)

                                CircleButton {
                                    icon: "󰅁"
                                    onActivated: win.openedId = ""
                                }

                                NLabel {
                                    text: win.tab === "you" ? "For You" : "Library"
                                    dim: false
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Image {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(180)
                                visible: {
                                    const p = win.detailItem?.path ?? "";
                                    return /\.(png|jpe?g|webp)$/i.test(p);
                                }
                                source: {
                                    const p = win.detailItem?.path ?? "";
                                    return p !== "" ? ("file://" + p) : "";
                                }
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.height: Theme.px(180)
                            }

                            VoiceBar {
                                Layout.fillWidth: true
                                visible: win.isAudio(win.detailItem?.path ?? "")
                                path: win.isAudio(win.detailItem?.path ?? "")
                                    ? (win.detailItem.path ?? "") : ""
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(6)

                                NLabel { text: "For You"; dim: true }

                                Text {
                                    Layout.fillWidth: true
                                    text: (win.detailItem?.when ?? "") !== ""
                                        ? win.whenPretty(win.detailItem.when)
                                        : (win.detailItem?.forYou
                                            ? "Listed, no time"
                                            : "Not listed")
                                    color: (win.detailItem?.when ?? "") !== ""
                                        ? Theme.c.on : Theme.c.onFaint
                                    font.family: Theme.f.display
                                    font.pixelSize: Theme.px(16)
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(6)

                                    NPillButton {
                                        text: "Tomorrow 9:00"
                                        onActivated: {
                                            if (win.detailItem)
                                                Essentials.setWhen(win.detailItem.id, win.tomorrowNine());
                                        }
                                    }
                                    NPillButton {
                                        text: "+1 h"
                                        onActivated: {
                                            if (win.detailItem)
                                                Essentials.setWhen(win.detailItem.id, win.plusHour());
                                        }
                                    }
                                    NPillButton {
                                        text: "Not For You"
                                        danger: (win.detailItem?.when ?? "") !== ""
                                            || win.detailItem?.forYou === true
                                        onActivated: {
                                            if (win.detailItem)
                                                Essentials.hideFromYou(win.detailItem.id);
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (win.detailItem?.mind === "pending")
                                    ? "Mind…"
                                    : ((win.detailItem?.title ?? "") !== ""
                                        ? win.detailItem.title
                                        : (win.detailItem?.kind ?? ""))
                                color: Theme.c.on
                                font.family: Theme.f.sans
                                font.pixelSize: Theme.f.big
                                wrapMode: Text.Wrap
                                opacity: (win.detailItem?.mind === "pending") ? 0.4 : 1
                                Behavior on opacity {
                                    NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(2)

                                NLabel { text: "Captured"; dim: true }

                                Text {
                                    Layout.fillWidth: true
                                    text: win.atLong(win.detailItem?.at ?? "")
                                    color: Theme.c.on
                                    font.family: Theme.f.mono
                                    font.pixelSize: Theme.f.small
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: (win.detailItem?.kind ?? "") !== ""
                                text: (win.detailItem?.kind ?? "")
                                    + (win.detailItem?.mind === "pending" ? " · mind" : "")
                                color: Theme.c.onDim
                                font.family: Theme.f.sans
                                font.pixelSize: Theme.f.small
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: {
                                    const s = win.detailItem?.summary ?? "";
                                    return s !== "" && s !== (win.detailItem?.title ?? "");
                                }
                                text: win.detailItem?.summary ?? ""
                                color: (win.detailItem?.mind === "error" || win.detailItem?.mind === "nokey")
                                    ? Theme.c.red : Theme.c.onDim
                                font.family: Theme.f.sans
                                font.pixelSize: Theme.f.body
                                wrapMode: Text.Wrap
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: {
                                    const t = win.detailItem?.text ?? "";
                                    const s = win.detailItem?.summary ?? "";
                                    return t !== "" && t !== s && t !== (win.detailItem?.title ?? "");
                                }
                                text: win.detailItem?.text ?? ""
                                color: Theme.c.onDim
                                font.family: Theme.f.sans
                                font.pixelSize: Theme.f.small
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: win.detailItem?.actions ?? []
                                Text {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "·  " + modelData
                                    color: Theme.c.on
                                    font.family: Theme.f.sans
                                    font.pixelSize: Theme.f.small
                                    wrapMode: Text.Wrap
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: (win.detailItem?.tags ?? []).length > 0
                                text: (win.detailItem?.tags ?? []).join("  ·  ")
                                color: Theme.c.onFaint
                                font.family: Theme.f.sans
                                font.pixelSize: Theme.f.micro
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.px(6)
                                spacing: Theme.px(6)
                                visible: win.detailItem !== null

                                NPillButton {
                                    visible: Config.mindBackend !== "stub"
                                    text: (win.detailItem?.mind === "gemini"
                                        || win.detailItem?.mind === "ollama")
                                        ? "Again" : "Ask"
                                    onActivated: if (win.detailItem) Essentials.mind(win.detailItem.id)
                                }

                                NPillButton {
                                    text: "Copy"
                                    onActivated: if (win.detailItem) Essentials.copyItem(win.detailItem)
                                }

                                NPillButton {
                                    visible: (win.detailItem?.path ?? "") !== ""
                                        && !win.isAudio(win.detailItem?.path ?? "")
                                    text: "Open"
                                    onActivated: if (win.detailItem) Essentials.openItem(win.detailItem)
                                }

                                Item { Layout.fillWidth: true }

                                NPillButton {
                                    text: "Drop"
                                    danger: true
                                    onActivated: {
                                        if (!win.detailItem)
                                            return;
                                        const id = win.detailItem.id;
                                        win.openedId = "";
                                        Essentials.remove(id);
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.px(8)
                        visible: list.count === 0 && !Essentials.busy && win.detailItem === null
                        width: parent.width - Theme.pad * 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.tab === "you"
                                ? "Nothing needs you yet"
                                : "Dump a thought"
                            color: Theme.c.onFaint
                            font.family: Theme.f.display
                            font.pixelSize: Theme.px(16)
                            font.letterSpacing: 1.0
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: win.tab === "you"
                            text: Config.mindBackend === "gemini"
                                ? (Essentials.hasGeminiKey
                                    ? "Dates and reminders land here"
                                    : "Add a Gemini key in settings")
                                : "Dates and reminders land here"
                            color: Theme.c.onFaint
                            font.family: Theme.f.sans
                            font.pixelSize: Theme.f.small
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.c.outline
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.pad
                    spacing: Theme.px(10)

                    NField {
                        id: dump
                        Layout.fillWidth: true
                        placeholder: "Dump a thought, or = for qalc"
                        onEscaped: GlobalState.essentialOpen = false
                        onFocusedChanged: if (focused) win.grabKeys = true
                        onSubmitted: (v) => {
                            if (v.trim() !== "")
                                win.dumpNow();
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: Theme.px(6)
                        columnSpacing: Theme.px(6)

                        Repeater {
                            model: [
                                { icon: "󰠮", label: "Note", kind: "note" },
                                { icon: "󰅌", label: "Clip", kind: "clip" },
                                { icon: "󰄀", label: "Snip", kind: "snip" },
                                { icon: "󰈚", label: "OCR",  kind: "ocr"  },
                                { icon: "󰑊", label: "Rec",  kind: "rec"  },
                                { icon: "󰎈", label: "Song", kind: "song" }
                            ]

                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool lit:
                                    (modelData.kind === "note" && dump.text.trim() !== "")
                                    || (modelData.kind === "rec" && Recorder.recording)
                                    || (modelData.kind === "song" && Songrec.listening)
                                readonly property bool danger:
                                    modelData.kind === "rec" && Recorder.recording
                                readonly property bool dim:
                                    modelData.kind === "song" && !Songrec.available

                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(56)
                                radius: Theme.r.chip
                                color: tile.danger ? Theme.c.red
                                     : (tile.lit ? Theme.c.on
                                     : (tileMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2))
                                opacity: tile.dim ? 0.4 : 1
                                Behavior on color { ColorAnimation { duration: Theme.fast } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Theme.px(2)
                                    color: Theme.c.red
                                    visible: tileMa.containsMouse && !tile.lit && !tile.danger
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(5)

                                    NIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tile.modelData.icon
                                        size: Theme.px(18)
                                        color: (tile.lit && !tile.danger) ? Theme.c.surface : Theme.c.on
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tile.modelData.label
                                        color: (tile.lit && !tile.danger) ? Theme.c.surface : Theme.c.on
                                        font.family: Theme.f.sans
                                        font.pixelSize: Theme.f.small
                                        font.letterSpacing: 0.4
                                    }
                                }

                                MouseArea {
                                    id: tileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: tile.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onPressed: {
                                        if (tile.dim)
                                            return;
                                        win.grabKeys = true;
                                        switch (tile.modelData.kind) {
                                        case "note": win.dumpNow(); break;
                                        case "clip": Essentials.addClip(); break;
                                        case "snip": Essentials.snip(); break;
                                        case "ocr":  Essentials.ocr(); break;
                                        case "rec":  Essentials.record(); break;
                                        case "song": Essentials.song(); break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(58)
                    Layout.bottomMargin: Theme.px(6)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(8)

                        Rectangle {
                            width: Theme.px(44)
                            height: width
                            radius: width / 2
                            color: closeMa.containsMouse ? Theme.c.surface3 : Theme.c.surface2
                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            NIcon {
                                anchors.centerIn: parent
                                text: "󰅖"
                                size: Theme.px(14)
                                color: Theme.c.on
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalState.essentialOpen = false
                            }
                        }

                        Rectangle {
                            height: Theme.px(44)
                            radius: height / 2
                            color: Theme.c.surface2
                            implicitWidth: tabRow.implicitWidth + Theme.px(10)

                            Row {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: Theme.px(4)

                                Rectangle {
                                    id: youSeg
                                    readonly property bool on: win.tab === "you"
                                    width: on ? youInner.implicitWidth + Theme.px(20) : Theme.px(40)
                                    height: Theme.px(36)
                                    radius: height / 2
                                    color: on ? Theme.c.surface3 : "transparent"
                                    Behavior on width {
                                        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                                    }
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    Row {
                                        id: youInner
                                        anchors.centerIn: parent
                                        spacing: Theme.px(8)

                                        Item {
                                            width: Theme.px(14)
                                            height: Theme.px(14)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Repeater {
                                                model: [
                                                    { x: 5.5, y: 0 }, { x: 11, y: 5.5 },
                                                    { x: 5.5, y: 11 }, { x: 0, y: 5.5 }
                                                ]
                                                Rectangle {
                                                    required property var modelData
                                                    width: Theme.px(3)
                                                    height: width
                                                    radius: width / 2
                                                    x: Theme.px(modelData.x)
                                                    y: Theme.px(modelData.y)
                                                    color: youSeg.on ? Theme.c.on : Theme.c.onDim
                                                }
                                            }
                                        }

                                        Text {
                                            visible: youSeg.on
                                            text: "For You"
                                            color: Theme.c.on
                                            font.family: Theme.f.sans
                                            font.pixelSize: Theme.f.small
                                            font.letterSpacing: 0.3
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.tab = "you"
                                    }
                                }

                                Rectangle {
                                    id: libSeg
                                    readonly property bool on: win.tab === "lib"
                                    width: on ? libInner.implicitWidth + Theme.px(20) : Theme.px(40)
                                    height: Theme.px(36)
                                    radius: height / 2
                                    color: on ? Theme.c.surface3 : "transparent"
                                    Behavior on width {
                                        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                                    }
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    Row {
                                        id: libInner
                                        anchors.centerIn: parent
                                        spacing: Theme.px(8)

                                        Item {
                                            width: Theme.px(14)
                                            height: Theme.px(14)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Repeater {
                                                model: [
                                                    { x: 2, y: 9 }, { x: 6.5, y: 1.5 }, { x: 11, y: 7.5 }
                                                ]
                                                Rectangle {
                                                    required property var modelData
                                                    width: Theme.px(3)
                                                    height: width
                                                    radius: width / 2
                                                    x: Theme.px(modelData.x)
                                                    y: Theme.px(modelData.y)
                                                    color: libSeg.on ? Theme.c.on : Theme.c.onDim
                                                }
                                            }
                                        }

                                        Text {
                                            visible: libSeg.on
                                            text: "Library"
                                            color: Theme.c.on
                                            font.family: Theme.f.sans
                                            font.pixelSize: Theme.f.small
                                            font.letterSpacing: 0.3
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.tab = "lib"
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: Theme.px(44)
                            height: width
                            radius: width / 2
                            color: (win.searching || searchMa.containsMouse)
                                ? Theme.c.surface3 : Theme.c.surface2
                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            NIcon {
                                anchors.centerIn: parent
                                text: "󰍉"
                                size: Theme.px(14)
                                color: win.searching ? Theme.c.on : Theme.c.onDim
                            }

                            MouseArea {
                                id: searchMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.searching = !win.searching;
                                    if (win.searching) {
                                        win.tab = "lib";
                                        find.takeFocus();
                                    } else {
                                        find.clear();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
