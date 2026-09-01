pragma Singleton

import QtQuick
import Quickshell
import ".."

// The Glyph Bar's shape. Everything about what it is saying lives in
// GlyphEvents, which the Strip reads too.
//
// The hardware, so none of this is invented: Nothing's own developer kit
// lists Phone (4a) as A1 to A6, six zones, A1 at the top. Under them are
// sixty-three mini-LEDs, nine to a segment, but that is the control
// granularity and not the appearance: they sit behind a bleed-free
// diffuser, so what you see is six solid squares of light. A seventh
// lights only while the camera is recording, and the kit does not expose
// it, which is why it is the one thing developers cannot borrow.
Singleton {
    id: root

    readonly property int segments: 6
    readonly property int lamps: 9

    // Geometry, named once. The strip lays itself out from these and the
    // plate around it sizes itself from the same numbers, so the black
    // never ends up with a margin the lamps do not fill.
    readonly property real gap: 0.17          // of a segment
    readonly property real aspect: 7 + 6 * root.gap
}
