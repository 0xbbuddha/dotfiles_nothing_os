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
    font.pixelSize: size
    color: Theme.c.on
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    transform: Translate { x: root.dx; y: root.dy }
}
