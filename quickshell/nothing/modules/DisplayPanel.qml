import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// SUPER+P: the screens, and where they sit.
//
// Hyprland can do all of this and none of it is reachable without a
// terminal: you either type a monitor line from memory or open the config
// and reload. Every other desktop answers SUPER+P with four arrangements
// and a picture, so this does too, and adds the one thing the command line
// genuinely cannot give you - a map you can drag a screen around on.
//
// The four arrangements are named after what they do. Nobody has ever
// known, on the first read, which display "Second screen only" meant.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    property bool open: GlobalState.displaysOpen

    color: "transparent"
    visible: open && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-displays"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // The screen the right-hand column is about.
    property string sel: ""
    readonly property var chosen: Displays.byName(win.sel)

    // Land on the screen you are looking at, which is the one you reached
    // for the shortcut on.
    function ensureSel(): void {
        if (win.sel !== "" && Displays.byName(win.sel))
            return;
        const foc = Displays.screens.find(s => s.focused);
        win.sel = foc?.name ?? (Displays.active[0]?.name ?? "");
    }

    onOpenChanged: {
        if (!win.open)
            return;
        Displays.refresh();
        win.sel = "";
        win.ensureSel();
    }

    // hyprctl answers a moment after the panel is up, so the choice has to
    // survive being made against an empty list: without this the panel
    // opens on no screen at all and says it has no modes.
    Connections {
        target: Displays
        function onScreensChanged(): void {
            if (win.open)
                win.ensureSel();
        }
    }

    // ── Arrangements ──────────────────────────────────────────────────
    // Two shapes plus one "only this one" per screen: with two screens
    // that is exactly the four everyone knows, and with three it stays
    // honest instead of pretending there is a second screen.
    readonly property var arrangements: {
        const out = [
            { key: "extend", label: "Extend", kind: "extend" },
            { key: "duplicate", label: "Duplicate", kind: "duplicate" }
        ];
        for (let i = 0; i < Displays.screens.length; i++) {
            const s = Displays.screens[i];
            out.push({ key: "only:" + s.name, label: "Only " + s.name,
                       kind: "only", side: i === 0 ? 0 : 1 });
        }
        return out;
    }

    // What the current layout already is, so the matching tile reads as
    // pressed rather than as an offer.
    readonly property string mode: {
        const on = Displays.active;
        if (on.length === 0)
            return "";
        if (on.length === 1)
            return "only:" + on[0].name;
        if (on.some(s => s.mirrorOf !== ""))
            return "duplicate";
        return "extend";
    }

    function arrange(a: var): void {
        if (a.kind === "extend")
            Displays.extend();
        else if (a.kind === "duplicate")
            Displays.duplicate();
        else
            Displays.only(a.key.substring(5));
    }

    // ── The map ───────────────────────────────────────────────────────
    // A screen at scale 2 occupies half the desktop it is worth in pixels,
    // and the map is a picture of the desktop, so logical size throughout.
    function logicalW(s: var): int { return Math.round(s.w / (s.scale > 0 ? s.scale : 1)); }
    function logicalH(s: var): int { return Math.round(s.h / (s.scale > 0 ? s.scale : 1)); }

    // Dropped where it nearly lines up, put it exactly there: a gap of
    // eleven pixels between two screens is never what anybody wanted.
    function snap(name: string, lx: real, ly: real): var {
        const s = Displays.byName(name);
        if (!s)
            return { x: lx, y: ly };
        const w = win.logicalW(s), h = win.logicalH(s);
        const tol = 90;
        let bx = lx, by = ly;
        let bestX = tol, bestY = tol;
        for (const o of Displays.active) {
            if (o.name === name)
                continue;
            const ow = win.logicalW(o), oh = win.logicalH(o);
            for (const cx of [o.x + ow, o.x - w, o.x, o.x + ow - w]) {
                const d = Math.abs(lx - cx);
                if (d < bestX) { bestX = d; bx = cx; }
            }
            for (const cy of [o.y + oh, o.y - h, o.y, o.y + oh - h]) {
                const d = Math.abs(ly - cy);
                if (d < bestY) { bestY = d; by = cy; }
            }
        }
        return { x: Math.round(bx), y: Math.round(by) };
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: GlobalState.displaysOpen = false }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        // While a change is on trial the keys belong to it: the panel has
        // the keyboard, so Escape undoes rather than closing over the
        // question, and Enter accepts.
        Keys.onEscapePressed: {
            if (Displays.confirming)
                Displays.revert();
            else
                GlobalState.displaysOpen = false;
        }
        Keys.onReturnPressed: if (Displays.confirming) Displays.keep()
        Keys.onEnterPressed: if (Displays.confirming) Displays.keep()

        NCard {
            id: sheet
            anchors.centerIn: parent
            width: Math.min(Theme.px(920), parent.width - Theme.px(96))
            height: Math.min(Theme.px(660), parent.height - Theme.px(80))
            clip: true

            scale: win.visible ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

            DotField {
                anchors.fill: parent
                step: Theme.px(15)
                dotRadius: Theme.px(1)
                baseAlpha: 0.4
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Header ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.pad
                    Layout.bottomMargin: Theme.px(10)
                    spacing: Theme.px(14)

                    ColumnLayout {
                        spacing: Theme.px(2)
                        NLabel { text: "N O T H I N G" }
                        NText {
                            text: "Displays"
                            font.pixelSize: Theme.px(30)
                            font.family: Theme.f.display
                        }
                    }

                    Item { Layout.fillWidth: true }

                    NLabel {
                        text: Displays.active.length + " of " + Displays.screens.length + " on"
                        font.pixelSize: Theme.f.small
                    }

                    CircleButton {
                        icon: "󰑐"
                        size: Theme.px(26)
                        onActivated: Displays.refresh()
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(26)
                        onActivated: GlobalState.displaysOpen = false
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // ── Arrangement and map ───────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: Theme.pad
                        spacing: Theme.px(10)

                        NLabel { text: "Arrangement" }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: Theme.px(6)
                            rowSpacing: Theme.px(6)

                            Repeater {
                                model: win.arrangements

                                Rectangle {
                                    id: tile
                                    required property var modelData
                                    readonly property bool active: win.mode === modelData.key

                                    Layout.fillWidth: true
                                    implicitHeight: Theme.px(72)
                                    radius: Theme.r.chip
                                    color: tile.active ? Theme.c.on
                                         : (tma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    readonly property color ink:
                                        tile.active ? Theme.c.surface : Theme.c.on
                                    readonly property color inkDim:
                                        tile.active ? Qt.rgba(Theme.c.surface.r, Theme.c.surface.g,
                                                              Theme.c.surface.b, 0.35)
                                                    : Theme.c.onFaint

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.px(7)

                                        // Two little screens saying what the
                                        // arrangement does, which is faster to
                                        // read than the word under it.
                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: Theme.px(40)
                                            implicitHeight: Theme.px(20)

                                            readonly property bool dup:
                                                tile.modelData.kind === "duplicate"
                                            readonly property bool only:
                                                tile.modelData.kind === "only"

                                            Rectangle {
                                                x: 0
                                                y: parent.dup ? Theme.px(4) : 0
                                                width: Theme.px(18)
                                                height: Theme.px(14)
                                                radius: Theme.px(3)
                                                color: (parent.only && tile.modelData.side === 1)
                                                    ? "transparent" : tile.ink
                                                border.width: 1
                                                border.color: (parent.only && tile.modelData.side === 1)
                                                    ? tile.inkDim : "transparent"
                                            }

                                            Rectangle {
                                                x: parent.dup ? Theme.px(9) : Theme.px(22)
                                                y: parent.dup ? 0 : 0
                                                width: Theme.px(18)
                                                height: Theme.px(14)
                                                radius: Theme.px(3)
                                                color: (parent.only && tile.modelData.side === 0)
                                                    ? "transparent"
                                                    : (parent.dup ? tile.ink : tile.ink)
                                                border.width: 1
                                                border.color: (parent.only && tile.modelData.side === 0)
                                                    ? tile.inkDim : "transparent"
                                                opacity: parent.dup ? 0.55 : 1
                                            }
                                        }

                                        NText {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.maximumWidth: tile.width - Theme.px(10)
                                            elide: Text.ElideRight
                                            text: tile.modelData.label
                                            font.pixelSize: Theme.f.tiny
                                            color: tile.active ? Theme.c.surface : Theme.c.onDim
                                        }
                                    }

                                    MouseArea {
                                        id: tma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !Displays.busy
                                        onClicked: win.arrange(tile.modelData)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.px(4)
                            NLabel { text: "Layout" }
                            Item { Layout.fillWidth: true }
                            NLabel {
                                text: "drag a screen to move it"
                                dim: true
                            }
                        }

                        // ── The map ───────────────────────────────────
                        Rectangle {
                            id: mapBox
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Theme.px(150)
                            radius: Theme.r.chip
                            color: Theme.c.surface2
                            clip: true

                            readonly property var b: Displays.bounds
                            readonly property real inset: Theme.px(18)
                            readonly property real f: Math.min(
                                (width - inset * 2) / Math.max(1, b.w),
                                (height - inset * 2) / Math.max(1, b.h))
                            readonly property real ox:
                                (width - b.w * f) / 2 - b.x * f
                            readonly property real oy:
                                (height - b.h * f) / 2 - b.y * f

                            Repeater {
                                model: Displays.active

                                Rectangle {
                                    id: plate
                                    required property var modelData
                                    readonly property bool active: win.sel === modelData.name

                                    // Dragging moves the rectangle; letting go
                                    // is what tells Hyprland. Moving it live
                                    // would refresh the list under the cursor
                                    // and yank the plate out from under it.
                                    property bool held: false

                                    width: win.logicalW(modelData) * mapBox.f
                                    height: win.logicalH(modelData) * mapBox.f
                                    x: mapBox.ox + modelData.x * mapBox.f
                                    y: mapBox.oy + modelData.y * mapBox.f

                                    radius: Theme.px(6)
                                    color: plate.active ? Theme.c.on : Theme.c.surface3
                                    border.width: modelData.focused ? Theme.px(2) : 1
                                    border.color: modelData.focused ? Theme.c.red : Theme.c.outline
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        NText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: plate.modelData.name
                                            font.weight: Font.Medium
                                            color: plate.active ? Theme.c.surface : Theme.c.on
                                        }
                                        NText {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: plate.height > Theme.px(44)
                                            text: plate.modelData.w + " x " + plate.modelData.h
                                            font.pixelSize: Theme.f.tiny
                                            color: plate.active ? Theme.c.surface : Theme.c.onDim
                                            opacity: 0.75
                                        }
                                        NText {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: plate.modelData.mirrorOf !== ""
                                                && plate.height > Theme.px(60)
                                            text: "mirrors " + plate.modelData.mirrorOf
                                            font.pixelSize: Theme.f.tiny
                                            color: Theme.c.red
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: plate.held ? Qt.ClosedHandCursor
                                                                : Qt.PointingHandCursor
                                        drag.target: plate
                                        drag.axis: Drag.XAndYAxis
                                        drag.smoothed: false

                                        onPressed: {
                                            win.sel = plate.modelData.name;
                                            plate.held = true;
                                        }
                                        onReleased: {
                                            plate.held = false;
                                            if (mapBox.f <= 0)
                                                return;
                                            const lx = (plate.x - mapBox.ox) / mapBox.f;
                                            const ly = (plate.y - mapBox.oy) / mapBox.f;
                                            const p = win.snap(plate.modelData.name, lx, ly);
                                            if (p.x === plate.modelData.x
                                                && p.y === plate.modelData.y) {
                                                // Put it back: the bindings were
                                                // broken by the drag.
                                                plate.x = Qt.binding(() =>
                                                    mapBox.ox + plate.modelData.x * mapBox.f);
                                                plate.y = Qt.binding(() =>
                                                    mapBox.oy + plate.modelData.y * mapBox.f);
                                                return;
                                            }
                                            Displays.setPosition(plate.modelData.name, p.x, p.y);
                                        }
                                    }
                                }
                            }

                            NText {
                                anchors.centerIn: parent
                                visible: Displays.active.length === 0
                                text: "No screen is on"
                                color: Theme.c.onDim
                            }
                        }
                    }

                    Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.c.outline }

                    // ── The chosen screen ─────────────────────────────
                    ColumnLayout {
                        Layout.preferredWidth: Theme.px(300)
                        Layout.fillHeight: true
                        Layout.margins: Theme.pad
                        spacing: Theme.px(10)

                        NLabel { text: "Screen" }

                        // Every screen, on or off: a screen you switched
                        // off has to stay reachable or there is no way back.
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.px(5)

                            Repeater {
                                model: Displays.screens

                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property bool active: win.sel === modelData.name

                                    implicitWidth: chipLabel.implicitWidth + Theme.px(20)
                                    implicitHeight: Theme.px(26)
                                    radius: Theme.r.pill
                                    color: chip.active ? Theme.c.on : Theme.c.surface2
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    NText {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: chip.modelData.name
                                        color: chip.active ? Theme.c.surface
                                             : (chip.modelData.disabled ? Theme.c.onFaint
                                                                        : Theme.c.onDim)
                                        font.strikeout: chip.modelData.disabled
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.sel = chip.modelData.name
                                    }
                                }
                            }
                        }

                        NText {
                            Layout.fillWidth: true
                            visible: win.chosen !== null
                            text: win.chosen?.label ?? ""
                            elide: Text.ElideRight
                            color: Theme.c.onDim
                            font.pixelSize: Theme.f.tiny
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: win.chosen !== null
                            NText { text: "On"; Layout.fillWidth: true }
                            NSwitch {
                                checked: !(win.chosen?.disabled ?? true)
                                // The last screen cannot be switched off:
                                // there would be nothing left to switch it
                                // back on from.
                                enabled: (win.chosen?.disabled ?? false)
                                    || Displays.active.length > 1
                                opacity: enabled ? 1 : 0.35
                                onToggled: (v) => Displays.setEnabled(win.sel, v)
                            }
                        }

                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

                        NLabel { text: "Resolution" }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Theme.px(110)
                            radius: Theme.r.chip
                            color: Theme.c.surface2
                            clip: true

                            ListView {
                                id: modes
                                anchors.fill: parent
                                anchors.margins: Theme.px(4)
                                model: win.chosen?.modes ?? []
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                delegate: Rectangle {
                                    id: modeRow
                                    required property var modelData
                                    readonly property bool active:
                                        modelData.w === (win.chosen?.w ?? 0)
                                        && modelData.h === (win.chosen?.h ?? 0)
                                        && modelData.hz === Math.round(win.chosen?.hz ?? 0)

                                    width: modes.width
                                    implicitHeight: Theme.px(28)
                                    radius: Theme.px(8)
                                    color: modeRow.active ? Theme.c.on
                                         : (mrm.containsMouse ? Theme.c.surface3 : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    NText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.px(10)
                                        text: modeRow.modelData.label
                                        color: modeRow.active ? Theme.c.surface : Theme.c.onDim
                                        font.family: Theme.f.mono
                                        font.pixelSize: Theme.f.tiny
                                    }

                                    MouseArea {
                                        id: mrm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !Displays.busy
                                        onClicked: Displays.setMode(win.sel, modeRow.modelData.id)
                                    }
                                }
                            }

                            NText {
                                anchors.centerIn: parent
                                visible: modes.count === 0
                                text: "No mode reported"
                                color: Theme.c.onFaint
                                font.pixelSize: Theme.f.tiny
                            }
                        }

                        NLabel { text: "Scale" }

                        SegmentedControl {
                            Layout.fillWidth: true
                            options: [
                                { label: "1x", value: 1 },
                                { label: "1.25x", value: 1.25 },
                                { label: "1.5x", value: 1.5 },
                                { label: "2x", value: 2 }
                            ]
                            current: win.chosen?.scale ?? 1
                            onPicked: (v) => Displays.setScale(win.sel, v)
                        }

                        NLabel { text: "Rotation" }

                        SegmentedControl {
                            Layout.fillWidth: true
                            options: [
                                { label: "0", value: 0 },
                                { label: "90", value: 1 },
                                { label: "180", value: 2 },
                                { label: "270", value: 3 }
                            ]
                            current: win.chosen?.transform ?? 0
                            onPicked: (v) => Displays.setTransform(win.sel, v)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.c.outline }

                // ── Keeping it ────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.pad
                    spacing: Theme.px(10)

                    Rectangle {
                        implicitWidth: Theme.px(7)
                        implicitHeight: Theme.px(7)
                        radius: width / 2
                        color: (Displays.confirming || !Displays.saved)
                            ? Theme.c.red : Theme.c.onFaint
                    }

                    NText {
                        Layout.fillWidth: true
                        // Two different lifetimes, and the shorter one wins
                        // the line: hyprctl eval lasts as long as the
                        // compositor, and a change on trial lasts fifteen
                        // seconds.
                        text: Displays.confirming
                            ? "Going back in " + Displays.countdown + "s unless you keep it"
                            : (Displays.saved
                               ? "Remembered. This layout comes back after a reload."
                               : "This layout lasts until Hyprland reloads.")
                        color: Theme.c.onDim
                        elide: Text.ElideRight
                    }

                    NPillButton {
                        text: "Undo"
                        visible: Displays.confirming
                        onActivated: Displays.revert()
                    }

                    NPillButton {
                        text: "Keep"
                        visible: Displays.confirming
                        onActivated: Displays.keep()
                    }

                    NPillButton {
                        text: "Forget"
                        visible: Displays.kept && !Displays.confirming
                        danger: true
                        onActivated: Displays.forget()
                    }

                    NPillButton {
                        // Not "Keep": that word belongs to the fifteen second
                        // question above, and the two would be asking
                        // different things under one name.
                        text: Displays.saved ? "Remembered" : "Remember"
                        visible: !Displays.confirming
                        opacity: Displays.saved ? 0.45 : 1
                        onActivated: if (!Displays.saved) Displays.save()
                    }
                }
            }
        }
    }
}
