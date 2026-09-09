import QtQuick
import ".."

// The grip that starts a drag, for one DragRow.
//
// A handle and not the whole row: these lists live inside a settings page
// that scrolls, and a row that dragged from anywhere would fight the
// Flickable for every vertical movement. Pressing a grip is unambiguous,
// and it leaves the rest of the row free to be clicked.
Item {
    id: root

    required property var row
    property real size: Theme.px(24)

    implicitWidth: root.size
    implicitHeight: root.size

    NIcon {
        anchors.centerIn: parent
        text: "󰇛"
        size: Theme.z.icon
        color: (root.row.dragging || ma.containsMouse)
            ? Theme.c.on : Theme.c.onFaint
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -Theme.px(3)
        hoverEnabled: true
        cursorShape: root.row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // The settings page is a Flickable and would otherwise take the
        // drag away after a few pixels of vertical movement.
        preventStealing: true

        // Where the pointer sat inside the row when it was picked up, so
        // the row does not jump to centre itself under the cursor.
        property real grab: 0

        // The row's top edge in the list's coordinates, kept because the
        // edge scroll has to move the row without the mouse moving.
        property real rowTop: 0

        // -1 scrolling up, 1 down, 0 not near an edge.
        property int edge: 0

        // The page these lists sit in scrolls, and the longest of them is
        // taller than the window. Found by walking up rather than passed
        // in: four call sites in three files, none of which should have to
        // know it is inside a Flickable.
        property var flick: null

        function findFlick(): var {
            let f = ma.parent;
            while (f && f.contentY === undefined)
                f = f.parent;
            return f ?? null;
        }

        // One place that turns a row position into everything that
        // follows from it, so the mouse and the edge scroll cannot drift
        // apart by each doing their own arithmetic.
        function place(y: real): void {
            const list = root.row.list;
            ma.rowTop = y;
            root.row.dragDy = y - list.slotY(root.row.index);
            list.to = Math.max(0, Math.min(list.count - 1,
                                           Math.round(y / list.step)));
        }

        onPressed: (m) => {
            const list = root.row.list;
            list.from = root.row.index;
            list.to = root.row.index;
            ma.grab = ma.mapToItem(list, 0, m.y).y - root.row.y;
            ma.rowTop = root.row.y;
            ma.edge = 0;
            ma.flick = ma.findFlick();
        }

        onPositionChanged: (m) => {
            const list = root.row.list;
            if (list.from !== root.row.index)
                return;
            // Read in the list's coordinates, not the handle's: the
            // handle travels with the row, so a delta measured against it
            // feeds back into itself and the row runs away down the page.
            ma.place(ma.mapToItem(list, 0, m.y).y - ma.grab);

            if (!ma.flick) {
                ma.edge = 0;
                return;
            }
            const margin = Theme.px(40);
            const vy = ma.mapToItem(ma.flick, 0, m.y).y;
            ma.edge = vy < margin ? -1
                    : (vy > ma.flick.height - margin ? 1 : 0);
        }

        // drop() before clearing the offset: it ends the drag, which puts
        // the Behavior back, so a row that landed where it started walks
        // home instead of snapping.
        onReleased: {
            ma.edge = 0;
            root.row.list.drop();
            root.row.dragDy = 0;
        }

        onCanceled: {
            const list = root.row.list;
            ma.edge = 0;
            list.from = -1;
            list.to = -1;
            root.row.dragDy = 0;
        }

        // Held against an edge, the page comes to the row. The row is
        // moved by exactly what the page scrolled: the pointer has not
        // moved, so the list slid under it by that much.
        Timer {
            running: ma.edge !== 0 && root.row.dragging
            interval: 16
            repeat: true
            onTriggered: {
                const f = ma.flick;
                if (!f) return;
                const max = Math.max(0, f.contentHeight - f.height);
                const wanted = f.contentY + ma.edge * Theme.px(9);
                const next = Math.max(0, Math.min(max, wanted));
                const moved = next - f.contentY;
                if (moved === 0) {
                    ma.edge = 0;
                    return;
                }
                f.contentY = next;
                ma.place(ma.rowTop + moved);
            }
        }
    }
}
