import QtQuick
import ".."

// Nerd Font icons. Square of `size` so centerIn aims at the glyph,
// not the font rectangle (ascent / descent).
Text {
    id: root
    property real size: Theme.z.iconM
    property real dx: 0
    property real dy: 0

    width: size
    height: size
    font.family: Theme.f.glyphs
    font.pixelSize: Theme.manga ? size * 1.08 : size
    // JetBrains Mono (what the Nerd Font patch is built on) keeps its
    // own weight axis through patching, so this actually draws a
    // heavier glyph rather than silently doing nothing - worth
    // confirming by eye once deployed.
    font.weight: Theme.manga ? Font.Black : Font.Normal
    color: Theme.c.on
    renderType: Text.QtRendering
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    transform: Translate { x: root.dx; y: root.dy }
}
