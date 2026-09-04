import QtQuick
import QtQuick.Shapes
import ".."

// One of Nothing's own icons, at whatever size you give it.
//
// Uniform scaling from the box the artwork occupies, so the icon keeps its
// proportions and whatever is left over is margin. Even-odd filling,
// because these shapes are cut rather than stacked: the magnifier is a
// hole in Essential Search's squircle, not a second shape painted over it,
// and winding-rule filling would plug it.
//
// Three parts at most. A ShapePath cannot be filled from a Repeater, so
// they are declared; three covers everything Nothing draws, and a fourth
// would be another block here rather than a silent truncation.
Item {
    id: root

    property string icon: ""
    property color color: Theme.c.on

    readonly property var set: NothingIcons.icons[root.icon] ?? null
    readonly property var parts: root.set?.parts ?? []

    // The part of the viewport the artwork actually occupies. Android's
    // monochrome icons are drawn small inside a large safe zone, so
    // scaling by the viewport alone rendered the launcher's mark at a
    // third of the weight of the others. Absent, the whole viewport is
    // the box, which is what Nothing's app icons use.
    readonly property var box: root.set?.box
        ?? { x: 0, y: 0, w: root.set?.viewport ?? 1, h: root.set?.viewport ?? 1 }

    readonly property real unit: root.set
        ? Math.min(width, height) / Math.max(root.box.w, root.box.h) : 0

    // A role, never a colour, so one icon reads on a dark dock and on a
    // light panel. "dim" is the same ink held back, not a grey: on a light
    // theme a fixed grey would be darker than the ink it sits behind.
    function inkFor(role: string): color {
        if (role === "accent")
            return Theme.c.red;
        if (role === "dim")
            return Qt.rgba(root.color.r, root.color.g, root.color.b,
                           root.color.a * 0.32);
        return root.color;
    }

    function pathAt(i: int): string {
        return root.parts[i]?.d ?? "";
    }

    // The box, centred; the shapes inside it slid so the artwork's own
    // origin lands where the box begins.
    Item {
        anchors.centerIn: parent
        width: root.box.w * root.unit
        height: root.box.h * root.unit

        Shape {
            x: -root.box.x * root.unit
            y: -root.box.y * root.unit
            width: root.set ? root.set.viewport * root.unit : 0
            height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.inkFor(root.parts[0]?.role ?? "on")
                fillRule: ShapePath.OddEvenFill
                strokeWidth: -1
                scale: Qt.size(root.unit, root.unit)
                PathSvg { path: root.pathAt(0) }
            }
            ShapePath {
                fillColor: root.inkFor(root.parts[1]?.role ?? "on")
                fillRule: ShapePath.OddEvenFill
                strokeWidth: -1
                scale: Qt.size(root.unit, root.unit)
                PathSvg { path: root.pathAt(1) }
            }
            ShapePath {
                fillColor: root.inkFor(root.parts[2]?.role ?? "on")
                fillRule: ShapePath.OddEvenFill
                strokeWidth: -1
                scale: Qt.size(root.unit, root.unit)
                PathSvg { path: root.pathAt(2) }
            }
        }
    }
}
