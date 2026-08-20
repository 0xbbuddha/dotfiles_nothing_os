import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../services"

// Workspace grid, each cell a screen thumbnail with windows at their real
// position. Click to go there, click a window to focus it, drag a window
// to move it between workspaces.
Item {
    id: root

    required property var screenInfo
    signal activated()          // emitted on navigate, to close the panel

    // Live thumbnails only while the preview is open.
    property bool live: false

    readonly property int rows: Config.workspaceRows
    readonly property int cols: Config.workspaceCols
    readonly property int count: rows * cols

    // Re-resolved when the monitor list changes: monitorFor() alone is a
    // one-shot call and would keep a dead HyprlandMonitor after a hotplug.
    readonly property var monitor: {
        Hyprland.monitors.values;
        return Hyprland.monitorFor(screenInfo);
    }
    readonly property real monW: monitor?.width ?? 1920
    readonly property real monH: monitor?.height ?? 1080
    readonly property real monX: monitor?.x ?? 0
    readonly property real monY: monitor?.y ?? 0
    readonly property real monScale: monitor?.scale ?? 1

    // Available width imposed by the caller, so the grid does not overflow
    // the screen at small resolutions.
    property real maxWidth: 1600

    readonly property real gap: Theme.px(8)

    // Tighten the scale if the grid does not fit the given width.
    readonly property real fitScale: {
        const natural = (monW / monScale);
        const avail = (maxWidth - (cols - 1) * gap) / cols;
        return Math.min(Config.workspaceScale, avail / natural);
    }

    readonly property real cellW: (monW / monScale) * fitScale
    readonly property real cellH: (monH / monScale) * fitScale

    // A window may live on a screen other than the one shown: it needs its
    // own monitor to be placed, otherwise the wrong offset is applied and
    // the thumbnail goes anywhere.
    function monitorOf(id: int): var {
        return (Hyprland.monitors?.values ?? []).find(m => m.id === id) ?? null;
    }

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1

    // Drag-and-drop state
    property string dragAddress: ""
    property int dropTarget: -1

    implicitWidth: cols * cellW + (cols - 1) * gap
    implicitHeight: rows * cellH + (rows - 1) * gap

    function windowsOf(wsId: int): var {
        return (Hyprland.toplevels?.values ?? []).filter(t => {
            const id = t.workspace?.id ?? t.lastIpcObject?.workspace?.id ?? -1;
            if (id !== wsId)
                return false;
            const o = t.lastIpcObject ?? {};
            if (o.hidden)
                return false;
            return true;
        });
    }

    function go(wsId: int): void {
        // Close the special workspace on the way, otherwise it would hide the switch.
        Hyprland.dispatch(`gotoWorkspaceSafe(${wsId})`);
        root.activated();
    }

    Grid {
        anchors.fill: parent
        rows: root.rows
        columns: root.cols
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            model: root.count

            Rectangle {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: root.focusedId === wsId
                readonly property bool targeted: root.dropTarget === wsId
                readonly property var wins: root.windowsOf(wsId)

                width: root.cellW
                height: root.cellH
                radius: Theme.r.chip
                color: Theme.c.surface2
                border.width: targeted ? 2 : (active ? 1 : 0)
                border.color: targeted ? Theme.c.on : Theme.c.red
                clip: true

                Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                Image {
                    anchors.fill: parent
                    source: Config.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.4
                }

                // Large number behind, in Ndot
                DisplayText {
                    anchors.centerIn: parent
                    text: cell.wsId
                    size: cell.height * 0.55
                    color: Theme.c.on
                    opacity: cell.wins.length > 0 ? 0.06 : 0.14
                }

                // Windows at scale
                Repeater {
                    model: cell.wins

                    Rectangle {
                        id: mini
                        required property var modelData
                        readonly property var ipc: modelData.lastIpcObject ?? ({})
                        readonly property string address: String(ipc.address ?? "")
                        readonly property string appClass: String(ipc.class ?? "")
                        readonly property bool dragging: root.dragAddress === address

                        // Position relative to ITS monitor, scaled down
                        readonly property var wmon: root.monitorOf(ipc.monitor ?? -1)
                        readonly property real wscale: wmon?.scale ?? 1
                        readonly property bool otherScreen:
                            (ipc.monitor ?? -1) !== (root.monitor?.id ?? -1)

                        x: ((ipc.at?.[0] ?? 0) - (wmon?.x ?? 0)) * root.fitScale / wscale
                        y: ((ipc.at?.[1] ?? 0) - (wmon?.y ?? 0)) * root.fitScale / wscale
                        width: Math.max(Theme.px(10),
                                        (ipc.size?.[0] ?? 100) * root.fitScale / wscale)
                        height: Math.max(Theme.px(8),
                                         (ipc.size?.[1] ?? 100) * root.fitScale / wscale)

                        radius: Theme.px(4)
                        color: wma.containsMouse ? Theme.c.surface3 : Theme.c.surface
                        border.width: 1
                        border.color: dragging ? Theme.c.red : Theme.c.outline
                        // Dimmed if it comes from another screen
                        opacity: dragging ? 0.55 : (otherScreen ? 0.5 : 1)
                        z: dragging ? 100 : 1
                        clip: true

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        ScreencopyView {
                            id: preview
                            anchors.fill: parent
                            captureSource: root.live ? (mini.modelData.wayland ?? null) : null
                            live: root.live
                            paintCursor: false
                            visible: hasContent
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            appId: mini.appClass
                            size: Math.min(parent.width, parent.height) * (preview.hasContent ? 0.22 : 0.5)
                            visible: size >= Theme.px(9)
                            opacity: preview.hasContent ? 0.95 : 1
                        }

                        MouseArea {
                            id: wma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                            property bool moved: false

                            onPressed: {
                                moved = false;
                                root.dragAddress = mini.address;
                            }

                            onPositionChanged: (m) => {
                                if (!pressed) return;
                                moved = true;
                                // Which workspace is under the cursor?
                                const p = mapToItem(root, m.x, m.y);
                                const c = Math.floor(p.x / (root.cellW + root.gap));
                                const r = Math.floor(p.y / (root.cellH + root.gap));
                                root.dropTarget = (c >= 0 && c < root.cols && r >= 0 && r < root.rows)
                                    ? r * root.cols + c + 1 : -1;
                            }

                            onReleased: (m) => {
                                const target = root.dropTarget;
                                root.dragAddress = "";
                                root.dropTarget = -1;

                                if (m.button === Qt.MiddleButton) {
                                    Hyprland.dispatch(
                                        `hl.dsp.window.close({ window = "address:${mini.address}" })`);
                                    return;
                                }
                                if (moved && target > 0 && target !== cell.wsId) {
                                    Hyprland.dispatch(`hl.dsp.window.move({ `
                                        + `window = "address:${mini.address}", `
                                        + `workspace = ${target}, follow = false })`);
                                    return;
                                }
                                if (!moved) {
                                    Hyprland.dispatch(
                                        `hl.dsp.focus({ window = "address:${mini.address}" })`);
                                    root.activated();
                                }
                            }
                        }

                        Tooltip {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: Theme.px(4)
                            text: mini.modelData.title
                            shown: wma.containsMouse && !mini.dragging
                            z: 200
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(cell.wsId)
                }

                // Window count
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.px(5)
                    width: Theme.px(16); height: Theme.px(16); radius: width / 2
                    color: Theme.c.surface
                    visible: cell.wins.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: cell.wins.length
                        color: Theme.c.onDim
                        font.family: Theme.f.mono
                        font.pixelSize: Theme.f.micro
                    }
                }
            }
        }
    }
}
