import QtQuick
import ".."

// One of Nothing's dot icons, at whatever size you give it.
//
// The set is a flat col,row list on a grid whose dots are exactly as wide
// as their cell, which is what makes the shapes read as solid where they
// are meant to and as separate dots where they are not. Scaling is done by
// the pitch, never by scaling a bitmap: the dots stay round and the gaps
// stay honest at every size.
Item {
    id: root

    // A key into DotIcons.sets. An unknown one draws nothing rather than
    // a placeholder: an icon that guesses is worse than a gap.
    property string kind: ""
    property color color: Theme.c.on
    // Fraction of the cell the dot fills. Nothing's own is 1, dots edge to
    // edge; a hair under keeps the seams visible at widget size.
    property real fill: 0.92

    readonly property var set: DotIcons.sets[root.kind] ?? null

    readonly property real step: root.set
        ? Math.min(width / root.set.cols, height / root.set.rows) : 0

    implicitWidth: Theme.px(40)
    implicitHeight: Theme.px(40)

    Item {
        anchors.centerIn: parent
        width: root.set ? root.step * root.set.cols : 0
        height: root.set ? root.step * root.set.rows : 0

        Repeater {
            // Halved, because the set stores col and row interleaved.
            model: root.set ? root.set.cells.length / 2 : 0

            Rectangle {
                required property int index

                readonly property real d: root.step * root.fill

                width: d
                height: d
                radius: d / 2
                color: root.color
                x: root.set.cells[index * 2] * root.step + (root.step - d) / 2
                y: root.set.cells[index * 2 + 1] * root.step + (root.step - d) / 2
            }
        }
    }
}
