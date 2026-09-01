pragma Singleton

import QtQuick
import Quickshell

// The Glyph surfaces this shell knows how to drive.
//
// Nothing's Glyph Interface is not one lamp but a set of named zones: the
// developer kit addresses A1, B1, C1..C4 and a segmented D1_1..D1_8 strip,
// and the same hardware doubles as a progress bar. So this is a list from
// the start rather than a single matrix with the others bolted on later.
//
// Only what actually exists is listed. A surface named here but not built
// would show up in the launcher as a dead row, which is worse than absent.
Singleton {
    readonly property var surfaces: [
        {
            id: "matrix",
            label: "Glyph Matrix",
            hint: "The disc, and the toys it carries",
            glyph: "󰧵"
        },
        {
            id: "bar",
            label: "Glyph Bar",
            hint: "Six readings and the camera light",
            glyph: "󰕾"
        }
    ]

    function meta(id: string): var {
        return surfaces.find(s => s.id === id) ?? null;
    }
}
