import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Right-click the empty desktop to edit it: a thin catcher on the
// background layer, under every real widget tile (Desktop.qml and
// AppsColumn.qml sit above it on the Bottom layer with their own
// tile-only masks), so it only ever sees clicks that land on nothing.
//
// Full-area mask always, not toggled with edit mode: a layer-shell
// surface's input region gates whether a click reaches it at all, button
// included, so a right-click could never arrive if the area were zero
// until after the state it is meant to set. Left-clicks landing here did
// nothing before this existed either; they still do, unless editing is
// open, where one dismisses it - tapping away, the same idea a popover
// already closes on.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nothing-desktop-edit"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: catcher }

    // A plain right-click menu, not an immediate toggle: raised exactly
    // under the cursor the way one is on any other desktop, rather than
    // a fixed pill somewhere else on the screen.
    property bool menuOpen: false
    property real menuX: 0
    property real menuY: 0

    MouseArea {
        id: catcher
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
            if (m.button === Qt.RightButton) {
                win.menuX = Math.min(m.x, win.width - menu.width - Theme.px(8));
                win.menuY = Math.min(m.y, win.height - menu.height - Theme.px(8));
                win.menuOpen = true;
            } else if (win.menuOpen) {
                win.menuOpen = false;
            } else if (GlobalState.desktopEditOpen) {
                GlobalState.desktopEditOpen = false;
            }
        }
    }

    // The classic desktop right-click: edit it, then the same handful
    // of things every other desktop offers from the same menu rather
    // than only widget placement.
    readonly property var menuItems: [
        { icon: GlobalState.desktopEditOpen ? "󰄬" : "󰏫",
          label: GlobalState.desktopEditOpen ? "Done editing" : "Edit Desktop",
          run: () => { GlobalState.desktopEditOpen = !GlobalState.desktopEditOpen; } },
        { icon: "󰐕", label: "Add widget or app",
          run: () => { GlobalState.closeAll(); GlobalState.launcherNothingOpen = true; } },
        { sep: true },
        { icon: "󰔎", label: "Theme: " + Config.theme,
          run: () => {
              const order = ["dark", "light", "manga"];
              Config.theme = order[(order.indexOf(Config.theme) + 1) % order.length];
              Config.save();
          } },
        { icon: "󰋊", label: "Wallpaper…",
          run: () => { GlobalState.closeAll(); GlobalState.wallpaperPickerOpen = true; } },
        { icon: "󰒓", label: "Settings",
          run: () => { GlobalState.closeAll(); GlobalState.settingsOpen = true; } }
    ]

    Rectangle {
        id: menu
        x: win.menuX
        y: win.menuY
        visible: win.menuOpen
        width: Theme.px(190)
        height: col.implicitHeight + Theme.px(8)
        radius: Theme.r.tiny
        color: Theme.c.surface2
        border.width: 1
        border.color: Theme.c.outline
        z: 10

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.px(4)
            spacing: 0

            Repeater {
                model: win.menuItems

                Item {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: modelData.sep ? Theme.px(9) : Theme.px(32)

                    Rectangle {
                        visible: entry.modelData.sep === true
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.px(4)
                        implicitHeight: 1
                        color: Theme.c.outline
                    }

                    Rectangle {
                        visible: entry.modelData.sep !== true
                        anchors.fill: parent
                        radius: Theme.r.tiny
                        color: rowMa.containsMouse ? Theme.c.surface3 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(10)
                            spacing: Theme.px(8)

                            NIcon {
                                text: entry.modelData.icon ?? ""
                                size: Theme.z.icon
                                color: Theme.c.onDim
                            }
                            NText {
                                Layout.fillWidth: true
                                text: entry.modelData.label ?? ""
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                entry.modelData.run();
                                win.menuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
