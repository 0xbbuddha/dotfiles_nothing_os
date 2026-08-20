import QtQuick
import ".."

// Dot-matrix text - the real Nothing Ndot, plus the 5x7 font
// I used to draw by hand.
Text {
    property real size: Theme.px(40)

    font.family: Theme.f.display
    font.pixelSize: size
    // Ndot has tight round dots: a hint of letter-spacing airs the render.
    font.letterSpacing: size * 0.04
    color: Theme.c.on
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
}
