import QtQuick
import ".."

// Text with the shell's defaults already applied.
//
// Of the 112 sans-serif Text blocks in this shell, every one restated the
// family, 67 restated the same size and 44 the same colour. That is how a
// change of typeface becomes an edit in eighty files, and it is why the
// font declarations outnumbered the text blocks.
//
// The defaults are the measured majority, so a call site only says what
// makes it different: a size, a dimmer ink, a weight.
Text {
    color: Theme.c.on
    font.family: Theme.f.sans
    font.pixelSize: Theme.f.small
}
