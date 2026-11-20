import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../components/apps"
import "../services"

// Essential Apps pinned to the desktop, as a homescreen of tiles.
// Stock widgets keep the left column; these sit on the right.
PanelWindow {
    id: win
    required property var modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nothing-apps"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; right: true }
    implicitWidth: Theme.z.widgets + Theme.px(96)

    mask: Region { item: grid }

    readonly property var pinned: {
        MiniApps.stamp;
        const ids = Config.deskApps ?? [];
        const out = [];
        for (let i = 0; i < ids.length; i++) {
            const spec = MiniApps.specOf(ids[i]);
            if (spec)
                out.push(spec);
        }
        return out;
    }

    // Which slot a point in the grid falls nearest to while a tile is
    // held and dragged - same idea and same component as the widget
    // column's (modules/Desktop.qml): Flow keeps owning position and
    // animation, this only decides when a drag has crossed into a
    // neighbour's half.
    DragFlow {
        id: dragFlow
        // Same normalisation as Widget.qml's own sizeKey: anything but
        // "m" or "l" is small, not only a literal "s".
        sizes: win.pinned.map(spec => {
            const key = (spec.size === "m" || spec.size === "l") ? spec.size : "s";
            const w = (key === "s")
                ? Math.floor((Theme.z.widgets - Theme.gap) / 2) : Theme.z.widgets;
            const h = key === "s" ? w : (key === "m" ? Theme.px(148) : Theme.z.widgets);
            return { width: w, height: h };
        })
        maxWidth: Theme.z.widgets
        spacing: Theme.gap
        onSwapped: (from, to) => Config.swapDeskApp(from, to)
    }

    Flow {
        id: grid
        x: Theme.px(48)
        y: Theme.px(62)
        width: Theme.z.widgets
        spacing: Theme.gap

        Repeater {
            model: win.pinned

            Item {
                id: slot
                required property var modelData
                required property int index
                // Flow positions children by width/height, which a
                // plain Item does not fill in from implicitWidth on its
                // own the way a few specific types do.
                width: host.implicitWidth
                height: host.implicitHeight
                z: dragMa.pressed ? 10 : 0

                // Which tile a drop would trade places with.
                Rectangle {
                    anchors.fill: parent
                    visible: dragFlow.dragging && dragFlow.to === slot.index
                        && dragFlow.from !== slot.index
                    color: "transparent"
                    radius: Theme.r.chip
                    border.width: 2
                    border.color: Theme.c.red
                    z: 5
                }

                // Behind the tile's own buttons, not above them: most of
                // a tile has no button at all, so this is what a press
                // there reaches, and the small buttons - plus, minus,
                // edit, remove - stay on top and keep working everywhere,
                // edit mode or not.
                MouseArea {
                    id: dragMa
                    anchors.fill: parent
                    enabled: GlobalState.desktopEditOpen
                    cursorShape: Qt.OpenHandCursor
                    property real pressX: 0
                    property real pressY: 0
                    property real liveOffsetX: 0
                    property real liveOffsetY: 0

                    onPressed: (m) => {
                        dragMa.pressX = m.x;
                        dragMa.pressY = m.y;
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.from = slot.index;
                        dragFlow.to = slot.index;
                    }
                    onPositionChanged: (m) => {
                        if (!dragMa.pressed)
                            return;
                        dragMa.liveOffsetX = m.x - dragMa.pressX;
                        dragMa.liveOffsetY = m.y - dragMa.pressY;
                        const p = mapToItem(grid, m.x, m.y);
                        dragFlow.to = dragFlow.nearestIndex(p.x, p.y);
                    }
                    // Committed here, not as the pointer crosses each
                    // neighbour: see modules/Desktop.qml for why.
                    onReleased: {
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.drop();
                    }
                    onCanceled: {
                        dragMa.liveOffsetX = 0;
                        dragMa.liveOffsetY = 0;
                        dragFlow.from = -1;
                        dragFlow.to = -1;
                    }
                }

                // Rides a private offset on top of Flow's own position
                // while held, the same trick as the widget column's
                // (modules/Desktop.qml) - Flow still owns slot's x/y and
                // still animates everyone else making room.
                AppHost {
                    id: host
                    spec: slot.modelData
                    chrome: true
                    x: dragMa.pressed ? dragMa.liveOffsetX : 0
                    y: dragMa.pressed ? dragMa.liveOffsetY : 0
                    scale: dragMa.pressed ? 0.96 : 1
                    Behavior on x { enabled: !dragMa.pressed; NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on y { enabled: !dragMa.pressed; NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    onEdited: {
                        GlobalState.appsFocus = slot.modelData.id;
                        GlobalState.closeAll();
                        GlobalState.appsOpen = true;
                    }
                    onDropped: Config.removeDeskApp(slot.modelData.id)
                }
            }
        }
    }
}
