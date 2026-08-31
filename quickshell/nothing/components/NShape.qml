import QtQuick
import QtQuick.Shapes
import ".."

// One of Nothing's countdown shapes, filled, at whatever size you give it.
//
// Uniform scaling from the 150 box the paths were authored in, so a shape
// in a square tile stays the shape it is instead of being stretched to fit
// the tile. Whatever is left over is margin.
Item {
    id: root

    property int index: 0
    property color color: Theme.c.surface3

    readonly property real unit:
        Math.min(width, height) / NShapes.viewport

    Shape {
        anchors.centerIn: parent
        width: NShapes.viewport * root.unit
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            // The path is authored at 150; the scale is the whole of the
            // fitting, which is why nothing here has to know the shape.
            scale: Qt.size(root.unit, root.unit)
            PathSvg { path: NShapes.path(root.index) }
        }
    }
}
