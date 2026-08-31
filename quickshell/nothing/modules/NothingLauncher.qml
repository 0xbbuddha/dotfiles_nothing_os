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
// Widgets and the Glyph Matrix used to be two halves of a settings page,
// which put "which widgets exist" a long way from "what they look like".
// Here a widget is shown as itself, alive, next to the faces it can wear.
//
// The Glyph side is written as a list of surfaces rather than as one
// matrix: the real Glyph Interface is a set of named zones, a segmented
// strip and a progress bar among them, and more of them are coming here.
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

    property string tab: "widgets"

    function close(): void { GlobalState.launcherNothingOpen = false; }

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
        width: Math.min(Theme.px(620), parent.width - Theme.px(80))
        height: Math.min(Theme.px(720), parent.height - Theme.px(80))

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.px(14)

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(10)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    NLabel { text: "N O T H I N G" }
                    NText {
                        text: "Launcher"
                        font.pixelSize: Theme.f.huge
                        font.family: Theme.f.display
                    }
                }

                CircleButton {
                    icon: "󰅖"
                    onActivated: win.close()
                }
            }

            SegmentedControl {
                options: [
                    { label: "Widgets", value: "widgets" },
                    { label: "Glyph",   value: "glyph" }
                ]
                current: win.tab
                onPicked: (v) => win.tab = v
            }

            // Twelve families is nearly three thousand pixels of shelf in
            // a panel six hundred tall. Scrolling five screens to find out
            // whether a family exists is not browsing, it is searching
            // blind, so the families are named up front and each name
            // jumps to its shelf.
            Flickable {
                id: index
                Layout.fillWidth: true
                implicitHeight: Theme.px(30)
                visible: win.tab === "widgets"
                contentWidth: indexRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: indexRow
                    height: index.height
                    spacing: Theme.px(6)

                    Repeater {
                        model: WidgetRegistry.groups

                        NPillButton {
                            required property string modelData
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData + "  "
                                + WidgetRegistry.inGroup(modelData).length
                            onActivated: {
                                const it = shelves.itemAt(index);
                                if (!it)
                                    return;
                                // Clamped, or jumping to the last family
                                // scrolls past the end and springs back.
                                flick.contentY = Math.max(0, Math.min(
                                    it.y - Theme.px(8),
                                    flick.contentHeight - flick.height));
                            }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: (win.tab === "widgets" ? wCol : gCol).implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                // ── Widgets ───────────────────────────────────────────
                ColumnLayout {
                    id: wCol
                    width: flick.width
                    spacing: Theme.px(16)
                    visible: win.tab === "widgets"

                    // The master switch lived on the settings page that
                    // this replaced. Without it here it would have no home
                    // at all, and the desktop could not be turned off.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.px(50)
                        radius: Theme.r.chip
                        color: Theme.c.surface2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(14)
                            anchors.rightMargin: Theme.px(12)
                            spacing: Theme.px(10)

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                NText { text: "Show widgets on the desktop" }
                                NText {
                                    Layout.fillWidth: true
                                    text: "Off hides the lot without forgetting the order"
                                    color: Theme.c.onDim
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

                    // One shelf per family, scrolled sideways. A grid of
                    // every widget at once buried the tall ones and made
                    // the panel a wall; a shelf keeps the alternatives of
                    // one thing side by side, which is how you choose.
                    Repeater {
                        id: shelves
                        model: WidgetRegistry.groups

                        ColumnLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: Theme.px(6)

                            NLabel { text: modelData }

                            Flickable {
                                id: shelf
                                Layout.fillWidth: true
                                implicitHeight: Theme.px(210)
                                contentWidth: row.width
                                contentHeight: height
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                Row {
                                    id: row
                                    height: shelf.height
                                    spacing: Theme.px(10)

                                    Repeater {
                                        model: WidgetRegistry.inGroup(
                                            shelf.parent.modelData)

                                        WidgetChoice {
                                            required property var modelData
                                            meta: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }

                    WidgetTuning { Layout.fillWidth: true }

                    // Order matters again, so it has to be editable. The
                    // column stacks top to bottom in exactly this order.
                    NLabel {
                        Layout.topMargin: Theme.px(4)
                        text: "On the desktop"
                        visible: Config.widgets.length > 0
                    }

                    Repeater {
                        model: Config.widgets

                        Rectangle {
                            id: placed
                            required property string modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: Theme.px(44)
                            radius: Theme.r.chip
                            color: Theme.c.surface2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(14)
                                anchors.rightMargin: Theme.px(10)
                                spacing: Theme.px(10)

                                NIcon {
                                    text: WidgetRegistry.icon(placed.modelData)
                                    size: Theme.z.iconM
                                    Layout.preferredWidth: Theme.px(18)
                                }

                                NText {
                                    Layout.fillWidth: true
                                    text: WidgetRegistry.label(placed.modelData)
                                    elide: Text.ElideRight
                                }

                                NLabel {
                                    text: (placed.index + 1) + "/" + Config.widgets.length
                                }

                                CircleButton {
                                    icon: "󰁝"
                                    size: Theme.px(24)
                                    enabled: placed.index > 0
                                    opacity: enabled ? 1 : 0.25
                                    onActivated: Config.moveWidget(placed.index, -1)
                                }
                                CircleButton {
                                    icon: "󰁅"
                                    size: Theme.px(24)
                                    enabled: placed.index < Config.widgets.length - 1
                                    opacity: enabled ? 1 : 0.25
                                    onActivated: Config.moveWidget(placed.index, 1)
                                }
                                CircleButton {
                                    icon: "󰅖"
                                    size: Theme.px(24)
                                    onActivated: Config.removeWidget(placed.modelData)
                                }
                            }
                        }
                    }
                }

                // How far down this is, and how far there is to go. The
                // list gave no sign of its own length, which is what made
                // it feel like widgets were missing rather than below.
                Rectangle {
                    x: flick.width - width - Theme.px(2)
                    y: flick.contentY
                        + (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                        * (flick.height - height)
                    width: Theme.px(3)
                    height: Math.max(Theme.px(28),
                        flick.height * flick.height / Math.max(1, flick.contentHeight))
                    radius: width / 2
                    color: Theme.c.onFaint
                    visible: flick.contentHeight > flick.height
                }

                // ── Glyph ─────────────────────────────────────────────
                ColumnLayout {
                    id: gCol
                    width: flick.width
                    spacing: Theme.px(12)
                    visible: win.tab === "glyph"

                    Repeater {
                        model: GlyphRegistry.surfaces
                        GlyphSurface { required property var modelData; meta: modelData }
                    }
                }
            }
        }
    }
}
