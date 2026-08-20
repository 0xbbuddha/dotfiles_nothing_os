import QtQuick
import ".."

// The tiny ultra-tracked uppercase label, typical of the Nothing UI.
Text {
    property bool dim: true
    font.family: Theme.f.mono
    font.pixelSize: Theme.f.micro
    font.letterSpacing: Theme.f.track
    font.capitalization: Font.AllUppercase
    color: dim ? Theme.c.onDim : Theme.c.on
    renderType: Text.QtRendering
}
