pragma Singleton

import QtQuick
import Quickshell

// Nothing's own weather icons, dot for dot.
//
// Every one of these was read out of the Nothing Widgets APK rather than
// drawn by eye: their vector drawables are nothing but a list of circles,
// each of radius 4 on a pitch of 8, so a dot is exactly as wide as its
// cell and neighbours touch. Decoding them back to grid coordinates loses
// nothing, and it is the only way the shapes are actually theirs. Drawing
// "a sun made of dots" from memory is how you end up with something that
// is dotted but not Nothing.
//
// Cells are a flat list of col, row pairs. A list of points would be
// tidier to read and four times the objects to build, and these are
// rebuilt whenever the weather turns.
Singleton {
    id: root

    readonly property var sets: ({
        "sun": { cols: 9, rows: 9,
            cells: [0,4,1,1,1,7,2,3,2,4,2,5,3,2,3,3,3,4,3,5,3,6,4,0,4,2,4,3,4,4,4,5,4,6,4,8,5,2,5,3,5,4,5,5,5,6,6,3,6,4,6,5,7,1,7,7,8,4] },
        "cloud": { cols: 11, rows: 7,
            cells: [0,3,0,4,1,2,1,3,1,4,1,5,2,1,2,2,2,3,2,4,2,5,2,6,3,1,3,2,3,3,3,4,3,5,3,6,4,2,4,3,4,4,4,5,4,6,5,1,5,2,5,3,5,4,5,5,5,6,6,0,6,1,6,2,6,3,6,4,6,5,6,6,7,0,7,1,7,2,7,3,7,4,7,5,7,6,8,0,8,1,8,2,8,3,8,4,8,5,8,6,9,1,9,2,9,3,9,4,9,5,10,2,10,3,10,4] },
        "partly": { cols: 11, rows: 9,
            cells: [0,4,1,1,2,3,2,6,2,7,3,2,3,3,3,5,3,6,3,7,3,8,4,0,4,2,4,3,4,5,4,6,4,7,4,8,5,2,5,3,5,6,5,7,5,8,6,3,6,5,6,6,6,7,6,8,7,1,7,5,7,6,7,7,7,8,8,4,8,5,8,6,8,7,8,8,9,4,9,5,9,6,9,7,9,8,10,5,10,6,10,7] },
        "rain": { cols: 11, rows: 9,
            cells: [0,3,0,4,1,2,1,3,1,4,1,5,1,8,2,1,2,2,2,3,2,4,2,5,2,7,3,1,3,2,3,3,3,4,3,5,4,2,4,3,4,4,4,5,4,8,5,1,5,2,5,3,5,4,5,5,5,7,6,0,6,1,6,2,6,3,6,4,6,5,7,0,7,1,7,2,7,3,7,4,7,5,7,8,8,0,8,1,8,2,8,3,8,4,8,5,8,7,9,1,9,2,9,3,9,4,9,5,10,2,10,3,10,4] },
        "snow": { cols: 9, rows: 9,
            cells: [0,4,1,2,1,4,1,6,2,1,2,2,2,4,2,6,2,7,3,3,3,5,4,0,4,1,4,2,4,4,4,6,4,7,4,8,5,3,5,5,6,1,6,2,6,4,6,6,6,7,7,2,7,4,7,6,8,4] },
        "storm": { cols: 7, rows: 9,
            cells: [0,4,1,3,1,4,2,2,2,3,2,4,2,5,2,6,2,7,2,8,3,1,3,2,3,3,3,4,3,5,3,6,3,7,4,0,4,1,4,2,4,3,4,4,4,5,4,6,5,4,5,5,6,4] },
        "fog": { cols: 9, rows: 8,
            cells: [0,1,0,4,0,7,1,0,1,3,1,6,2,1,2,4,2,7,3,0,3,3,3,6,4,1,4,4,4,7,5,0,5,3,5,6,6,1,6,4,6,7,7,0,7,3,7,6,8,1,8,4,8,7] },
        "clearNight": { cols: 9, rows: 9,
            cells: [0,3,0,4,0,5,1,1,1,2,1,3,1,4,1,5,1,6,1,7,2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7,3,0,3,4,3,5,3,6,3,7,3,8,4,5,4,6,4,7,4,8,5,6,5,7,5,8,6,1,6,6,6,7,7,0,7,2,7,6,7,7,8,1,8,5,8,6] },
        "cloudyNight": { cols: 11, rows: 8,
            cells: [0,2,0,3,0,4,0,5,1,1,1,2,1,3,1,4,1,5,1,6,2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7,3,0,3,1,3,5,3,6,3,7,4,0,4,3,4,6,4,7,5,2,5,3,5,4,5,6,5,7,6,3,6,4,6,6,7,2,7,3,7,4,8,1,8,2,8,3,8,4,9,1,9,2,9,3,9,4,10,2,10,3] }
    })

    function has(kind: string): bool {
        return root.sets[kind] !== undefined;
    }

    // The night pair Nothing ships. Only the clear and cloudy skies have
    // one; rain at midnight looks like rain, and they draw it that way.
    function nightly(kind: string, night: bool): string {
        if (!night) return kind;
        if (kind === "sun") return "clearNight";
        if (kind === "cloud") return "cloudyNight";
        return kind;
    }
}
