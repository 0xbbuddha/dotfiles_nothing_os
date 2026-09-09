import QtQuick
import QtQuick.Layouts
import ".."

// A list whose rows are reordered by dragging them.
//
// It replaced a pair of up and down arrows on every row, which is four
// presses to move something three places and no sense of where it will
// land. It also positions its own rows rather than leaving that to a
// Column: the hole has to travel with the pointer, so a row's place
// depends on where the drag currently is and not only on its index.
//
// The rows are the caller's, not this component's. The four lists that
// use it look nothing alike past the first two columns, and a shared
// delegate would have needed a way to pass a ZonePicker into one and an
// application icon into another. So a call site keeps its own Repeater
// and wraps each row in a DragRow.
//
// Nothing here writes the order. A drag ends in one `reordered` signal
// and the owner of the list decides what that means, which is what keeps
// this usable by four lists stored four different ways.
Item {
    id: root

    property int count: 0
    property real rowHeight: Theme.px(34)
    property real rowSpacing: Theme.px(4)

    // The row being dragged and the index it would land on, both -1 when
    // nothing is happening.
    property int from: -1
    property int to: -1

    readonly property bool dragging: root.from >= 0
    readonly property real step: root.rowHeight + root.rowSpacing

    signal reordered(int from, int to)

    Layout.fillWidth: true
    implicitHeight: root.count === 0
        ? 0 : root.count * root.rowHeight + (root.count - 1) * root.rowSpacing

    function slotY(i: int): real { return i * root.step; }

    // Where row `i` sits while another row is in the air.
    //
    // Two steps: take the dragged row out of the list, which pulls
    // everything below it up one, then put it back at `to`, which pushes
    // everything from there down one. Done as one expression it reads as
    // arithmetic; done as two it is what your eyes see happening.
    function shifted(i: int): int {
        if (root.from < 0 || i === root.from)
            return i;
        const lifted = i > root.from ? i - 1 : i;
        return lifted >= root.to ? lifted + 1 : lifted;
    }

    // Called on release. Clears the drag first so the rows are back under
    // their plain bindings before the model changes underneath them.
    function drop(): void {
        const f = root.from;
        const t = root.to;
        root.from = -1;
        root.to = -1;
        if (f >= 0 && t >= 0 && f !== t)
            root.reordered(f, t);
    }
}
