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
//
// textFormat is plain on purpose: Text's own default (AutoText) sniffs
// the string and switches to rich text the moment it looks like HTML,
// which almost everything shown here is not supposed to be - a window
// title, a clipboard entry, a notification summary, a phone message, a
// process name. All of those are somebody else's text, not this
// shell's, and "<h1>" in a copied string becoming a giant heading (or
// "<img src=...>" making a request) is a rendering bug, not a feature.
// A call site that genuinely wants markup says so itself.
Text {
    color: Theme.c.on
    font.family: Theme.f.sans
    font.pixelSize: Theme.f.small
    textFormat: Text.PlainText
}
