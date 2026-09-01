import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../components/widgets"
import "../services"

// The Nothing Launcher: one place for everything that makes this desktop
// a Nothing desktop.
//
// Rebuilt around a rail. The first version stacked every family down one
// scrolling column, which was fine at eight widgets and two tabs and had
// become two thousand nine hundred pixels of content in a six hundred
// pixel window: five and a half screens, with nothing to say how much was
// left. Widgets were not missing, they were below, and there is no
// difference between those two from the reader's side.
//
// So one thing at a time. The rail names everything that exists and how
// much of it there is, the pane shows only what you picked, and nothing
// scrolls further than its own content. Bigger, too: a widget preview is
// the real widget at its real size, and it deserves room to be looked at.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData

    readonly property bool onFocusedMonitor:
        (Hyprland.focusedMonitor?.name ?? "") === (win.modelData?.name ?? "")

    property bool open: GlobalState.launcherNothingOpen

    color: "transparent"
    visible: open && onFocusedMonitor
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nothing-launcher"
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    function close(): void { GlobalState.launcherNothingOpen = false; }

    // ── What the rail lists ───────────────────────────────────────────
    //
    // Built from the registries, never spelled out: a family added to
    // WidgetRegistry appears here without anyone remembering to.
    readonly property var sections: {
        const out = [{ id: "desktop", label: "Desktop", group: "DESKTOP",
                       hint: "What is on it, and in what order", count: -1 }];
        for (const g of WidgetRegistry.groups)
            out.push({ id: "w:" + g, label: g, group: "WIDGETS",
                       hint: WidgetRegistry.inGroup(g).length
                             + " to choose from, one at a time",
                       count: WidgetRegistry.inGroup(g).length });
        for (const s of GlyphRegistry.surfaces)
            out.push({ id: "g:" + s.id, label: s.label, group: "GLYPH",
                       hint: s.hint, count: -1 });
        return out;
    }

    property string filter: ""

    readonly property var shown: {
        const q = win.filter.trim().toLowerCase();
        if (q === "")
            return win.sections;
        // A family matches on its own name or on any widget inside it, so
        // typing "battery" finds the family even though no family is
        // called that.
        return win.sections.filter(s => {
            if (s.label.toLowerCase().indexOf(q) >= 0)
                return true;
            if (!s.id.startsWith("w:"))
                return false;
            return WidgetRegistry.inGroup(s.id.slice(2))
                .some(w => w.label.toLowerCase().indexOf(q) >= 0
                        || (w.hint ?? "").toLowerCase().indexOf(q) >= 0);
        });
    }

    property string current: "desktop"
    readonly property var section:
        win.sections.find(s => s.id === win.current) ?? win.sections[0]

    // Never leave the pane on a section the filter has hidden.
    onShownChanged: {
        if (win.shown.length > 0
                && !win.shown.some(s => s.id === win.current))
            win.current = win.shown[0].id;
    }

    onVisibleChanged: if (!visible) { win.filter = ""; }

    Rectangle {
        anchors.fill: parent
        color: Theme.c.scrim
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }

    Item {
        anchors.fill: parent
        focus: win.visible
        Keys.onEscapePressed: win.close()
    }

    NCard {
        id: panel
        anchors.centerIn: parent
        // Nearly the screen. The old panel was sized for a list; this one
        // is sized for the widgets it shows at their real size.
        width: Math.min(Theme.px(1240), parent.width - Theme.px(96))
        height: Math.min(Theme.px(860), parent.height - Theme.px(80))
        clip: true

        // The house texture, barely there. It gives the panel a surface
        // instead of a void, and it is the same field the settings sheet
        // and the lock screen use.
        DotField {
            anchors.fill: parent
            dotColor: Theme.c.onFaint
            opacity: 0.25
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Rail ──────────────────────────────────────────────────
            Item {
                Layout.preferredWidth: Theme.px(268)
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.pad
                    spacing: Theme.px(14)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(2)
                        NLabel { text: "N O T H I N G" }
                        NText {
                            text: "Launcher"
                            font.pixelSize: Theme.px(30)
                            font.family: Theme.f.display
                        }
                    }

                    NField {
                        Layout.fillWidth: true
                        placeholder: "Find a widget"
                        onTextChanged: win.filter = text
                        onEscaped: {
                            if (text === "")
                                win.close();
                            else
                                text = "";
                        }
                    }

                    Flickable {
                        id: rail
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: railCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        ColumnLayout {
                            id: railCol
                            width: rail.width
                            spacing: Theme.px(2)

                            Repeater {
                                model: win.shown

                                ColumnLayout {
                                    id: entry
                                    required property var modelData
                                    required property int index

                                    readonly property bool heading:
                                        index === 0
                                        || win.shown[index - 1].group !== modelData.group

                                    Layout.fillWidth: true
                                    spacing: Theme.px(2)

                                    NLabel {
                                        Layout.topMargin: entry.index === 0
                                            ? 0 : Theme.px(12)
                                        Layout.bottomMargin: Theme.px(2)
                                        visible: entry.heading
                                        text: entry.modelData.group
                                    }

                                    Rectangle {
                                        readonly property bool on:
                                            win.current === entry.modelData.id

                                        Layout.fillWidth: true
                                        implicitHeight: Theme.px(38)
                                        radius: Theme.px(4)
                                        color: on ? Theme.c.surface2
                                                  : "transparent"

                                        // The mark of the current section
                                        // is a red rule down its edge, not
                                        // a filled block: the pane beside
                                        // it is already the loud half.
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Theme.px(2)
                                            height: parent.on ? Theme.px(20) : 0
                                            radius: 1
                                            color: Theme.c.red
                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: Theme.fast
                                                    easing.type: Theme.ease
                                                }
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.px(14)
                                            anchors.rightMargin: Theme.px(12)
                                            spacing: Theme.px(8)

                                            NText {
                                                Layout.fillWidth: true
                                                text: entry.modelData.label
                                                color: parent.parent.on
                                                    ? Theme.c.on : Theme.c.onDim
                                                elide: Text.ElideRight
                                            }

                                            NLabel {
                                                visible: entry.modelData.count >= 0
                                                text: String(entry.modelData.count)
                                                color: parent.parent.on
                                                    ? Theme.c.red : Theme.c.onFaint
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.current = entry.modelData.id
                                        }
                                    }
                                }
                            }

                            // Room under the last entry, or the footer
                            // sits on it and it reads as cut off.
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: Theme.px(10)
                            }

                            NText {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.px(20)
                                visible: win.shown.length === 0
                                text: "Nothing matches that."
                                color: Theme.c.onDim
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(10)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            NText { text: "Show widgets" }
                            NText {
                                Layout.fillWidth: true
                                text: "Off hides them, keeping the order"
                                color: Theme.c.onDim
                                font.pixelSize: Theme.f.tiny
                                elide: Text.ElideRight
                            }
                        }

                        DotSwitch {
                            checked: Config.showDesktopWidgets
                            onToggled: (v) => {
                                Config.showDesktopWidgets = v;
                                Config.save();
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.c.outline
            }

            // ── Pane ──────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.pad
                    spacing: Theme.px(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(12)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            NText {
                                text: win.section?.label ?? ""
                                font.pixelSize: Theme.px(26)
                                font.family: Theme.f.display
                            }
                            NText {
                                Layout.fillWidth: true
                                text: win.section?.hint ?? ""
                                color: Theme.c.onDim
                                font.pixelSize: Theme.f.tiny
                                elide: Text.ElideRight
                            }
                        }

                        CircleButton {
                            icon: "󰅖"
                            onActivated: win.close()
                        }
                    }

                    Flickable {
                        id: pane
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: paneCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        ColumnLayout {
                            id: paneCol
                            width: pane.width
                            spacing: Theme.px(16)

                            // ── Desktop ───────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: win.current === "desktop"
                                spacing: Theme.px(10)

                                NText {
                                    Layout.fillWidth: true
                                    visible: Config.widgets.length === 0
                                    text: "Nothing placed yet. Pick a family "
                                        + "on the left and click a widget."
                                    color: Theme.c.onDim
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: Config.widgets

                                    Rectangle {
                                        id: placed
                                        required property string modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: Theme.px(48)
                                        radius: Theme.px(4)
                                        color: Theme.c.surface2

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.px(16)
                                            anchors.rightMargin: Theme.px(12)
                                            spacing: Theme.px(12)

                                            NLabel {
                                                Layout.preferredWidth: Theme.px(22)
                                                text: String(placed.index + 1)
                                                color: Theme.c.red
                                            }

                                            NIcon {
                                                text: WidgetRegistry.icon(placed.modelData)
                                                size: Theme.z.iconM
                                                Layout.preferredWidth: Theme.px(20)
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                NText {
                                                    text: WidgetRegistry.label(placed.modelData)
                                                }
                                                NText {
                                                    Layout.fillWidth: true
                                                    text: WidgetRegistry.hint(placed.modelData)
                                                    color: Theme.c.onDim
                                                    font.pixelSize: Theme.f.tiny
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            CircleButton {
                                                icon: "󰁝"
                                                size: Theme.px(26)
                                                enabled: placed.index > 0
                                                opacity: enabled ? 1 : 0.25
                                                onActivated: Config.moveWidget(placed.index, -1)
                                            }
                                            CircleButton {
                                                icon: "󰁅"
                                                size: Theme.px(26)
                                                enabled: placed.index < Config.widgets.length - 1
                                                opacity: enabled ? 1 : 0.25
                                                onActivated: Config.moveWidget(placed.index, 1)
                                            }
                                            CircleButton {
                                                icon: "󰅖"
                                                size: Theme.px(26)
                                                onActivated: Config.removeWidget(placed.modelData)
                                            }
                                        }
                                    }
                                }

                                WidgetTuning {
                                    Layout.fillWidth: true
                                    Layout.topMargin: Theme.px(8)
                                }
                            }

                            // ── One family ────────────────────────────
                            //
                            // A grid, not the sideways shelf the old panel
                            // used. The shelf existed because the column
                            // was already too long to add height to; with
                            // one family on screen there is room to lay
                            // them out and be able to compare them.
                            Flow {
                                Layout.fillWidth: true
                                visible: (win.current ?? "").startsWith("w:")
                                spacing: Theme.px(12)

                                Repeater {
                                    model: (win.current ?? "").startsWith("w:")
                                        ? WidgetRegistry.inGroup(win.current.slice(2))
                                        : []

                                    WidgetChoice {
                                        required property var modelData
                                        meta: modelData
                                    }
                                }
                            }

                            // ── One Glyph surface ─────────────────────
                            Repeater {
                                model: (win.current ?? "").startsWith("g:")
                                    ? [GlyphRegistry.meta(win.current.slice(2))]
                                    : []

                                GlyphSurface {
                                    required property var modelData
                                    meta: modelData
                                    titled: false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
