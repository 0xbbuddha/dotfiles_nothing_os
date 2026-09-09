import QtQuick
import ".."

// One row of a DragList. Put the row's own content inside it.
//
// It carries no appearance of its own: it is a slot with a y, and the
// caller fills it. `dragDy` rather than moving `y` directly, because `y`
// is a binding on the row's place in the list and assigning to a bound
// property destroys the binding for good: the row would then never
// follow the list again.
Item {
    id: root

    required property var list
    required property int index

    // Offset from the row's slot while it is in the air.
    property real dragDy: 0

    readonly property bool dragging: root.list.from === root.index

    width: root.list.width
    height: root.list.rowHeight
    y: root.list.slotY(root.list.shifted(root.index)) + root.dragDy

    // Above the others while it travels, so it passes over them rather
    // than through them.
    z: root.dragging ? 2 : 1

    // The rows getting out of the way animate; the one under the pointer
    // must not, or it lags behind the hand holding it.
    Behavior on y {
        enabled: !root.dragging
        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
    }
}
