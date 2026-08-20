import QtQuick
import ".."

// Glyph drawn as a dot matrix, the panel's basic vocabulary.
//
// The pattern is given line by line, one character per dot: "0", " " and "."
// leave the dot off; everything else turns it on.
//
//     pattern: ["01110",
//               "10001",
//               "11111"]
//
// Off dots keep their place instead of vanishing: it is the ghost grid
// that makes the whole read as a display, not a floating drawing.
Item {
    id: root

    property var pattern: []
    property real dot: Theme.px(3)
    property real gap: Theme.px(2)
    property color onColor: Theme.c.on
    property color offColor: Theme.c.onFaint
    property real offOpacity: 1.0

    // Fraction of dots lit, in reading order. Used for cascade entries:
    // animating 0 to 1 reveals the glyph dot by dot.
    property real reveal: 1.0

    readonly property int rows: root.pattern.length
    readonly property int cols: root.rows > 0 ? String(root.pattern[0]).length : 0
    readonly property int total: root.rows * root.cols

    implicitWidth: root.cols > 0
        ? root.cols * root.dot + (root.cols - 1) * root.gap : 0
    implicitHeight: root.rows > 0
        ? root.rows * root.dot + (root.rows - 1) * root.gap : 0

    Grid {
        anchors.centerIn: parent
        columns: root.cols
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            model: root.total

            Rectangle {
                required property int index

                readonly property bool lit: {
                    const row = String(root.pattern[Math.floor(index / root.cols)] ?? "");
                    const ch = row[index % root.cols] ?? "0";
                    return ch !== "0" && ch !== " " && ch !== ".";
                }

                readonly property bool shown:
                    root.total > 0 && (index + 1) / root.total <= root.reveal + 0.0001

                width: root.dot
                height: root.dot
                radius: root.dot / 2
                color: lit ? root.onColor : root.offColor

                // Never "visible": the Grid would pack columns and the glyph
                // would warp on every state change.
                opacity: !shown ? 0 : (lit ? 1 : root.offOpacity)

                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
        }
    }
}
