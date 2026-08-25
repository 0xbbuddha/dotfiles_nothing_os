import QtQuick
import ".."

// One glyph per typed character, cycling through a set of patterns so a
// password reads as a sequence rather than a row of identical bullets.
//
// The reference rice cycles Material shapes here. This draws dot-matrix
// glyphs instead: the same vocabulary as the Glyph Matrix and the
// settings rail, which is what makes it look like it belongs.
Item {
    id: root

    property int count: 0
    // The glyph is 13 wide; the rest of the cell is the gap that keeps
    // one character from bleeding into the next. Too tight and the row
    // reads as one continuous dot field instead of a sequence.
    property real cell: Theme.px(22)
    property color color: Theme.c.on
    property bool alarm: false

    // Seven 3x3 patterns. Cycled by position, so the same password always
    // draws the same figure and a changed one is visible at a glance.
    // Chosen for contrast at a glance, not for variety on paper: a ring
    // and a full block differ by one dot and read as the same smudge.
    readonly property var patterns: [
        ["111", "111", "111"],   // block
        ["000", "010", "000"],   // point
        ["111", "101", "111"],   // ring
        ["010", "111", "010"],   // plus
        ["101", "010", "101"],   // cross
        ["110", "110", "000"],   // corner
        ["010", "010", "010"]    // bar
    ]

    implicitWidth: Math.max(0, root.count) * root.cell
    implicitHeight: root.cell

    Row {
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.count

            Item {
                id: slot
                required property int index
                width: root.cell
                height: root.cell

                DotMatrix {
                    anchors.centerIn: parent
                    pattern: root.patterns[slot.index % root.patterns.length]
                    dot: Theme.px(3)
                    gap: Theme.px(2)
                    onColor: root.alarm ? Theme.c.red : root.color
                    offColor: root.alarm ? Theme.c.red : root.color
                    // Barely there: the ghost grid is the Nothing idiom,
                    // but at this size it filled the gaps and welded the
                    // characters together.
                    offOpacity: 0.07
                }

                // Each character lands rather than appearing: the only
                // feedback that a keystroke registered, since the text
                // itself is never shown.
                scale: 0
                opacity: 0
                Component.onCompleted: land.start()

                ParallelAnimation {
                    id: land
                    NumberAnimation {
                        target: slot; property: "opacity"
                        to: 1; duration: Theme.fast
                    }
                    NumberAnimation {
                        target: slot; property: "scale"
                        from: 0.4; to: 1
                        duration: Theme.med; easing.type: Theme.ease
                    }
                }
            }
        }
    }
}
