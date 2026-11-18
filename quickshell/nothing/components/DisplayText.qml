import QtQuick
import ".."

// Dot-matrix text - the real Nothing Ndot, plus the 5x7 font
// I used to draw by hand.
Text {
    property real size: Theme.px(40)

    // Manga does not read Ndot's dot-matrix face as a title at all -
    // a heavy, condensed, already-installed system weight stands in
    // for the bold logo lettering a real manga title would use. No
    // new font package, so no risk of a missing-font fallback.
    font.family: Theme.manga ? "Noto Sans" : Theme.f.display
    font.weight: Theme.manga ? Font.Black : Font.Normal
    font.pixelSize: size
    // Ndot has tight round dots: a hint of letter-spacing airs the render.
    // Manga's own face is already tight and bold, so it gets none.
    font.letterSpacing: Theme.manga ? 0 : size * 0.04
    color: Theme.c.on
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
