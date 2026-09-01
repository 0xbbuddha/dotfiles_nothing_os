pragma Singleton

import QtQuick
import Quickshell

// How the Glyph behaves when something happens.
//
// On the phone this is the whole point of the Glyph Interface: you pick
// the rhythm, per contact, per app, per kind of event. It is a light that
// blinks in a shape you recognise from across the room, not a progress
// bar. The first version here filled the surface smoothly and drained it,
// which reads as loading, not as being told something.
//
// A pattern is a list of steps. Each step holds a duration and a value,
// and a kind that says how to read the value:
//
//   "level"  fill this fraction of the surface from the start
//   "point"  light only the zone at this fraction, nothing else
//   "zones"  light exactly these groups, of `g` groups across the surface
//
// Fractions and group indices, never zone names, because the same pattern
// has to play on six square segments and on three arcs of thirty-six
// zones. Naming zones would have tied every rhythm to one piece of
// hardware, and a rhythm you composed on the Bar would be lost the day you
// switched to the Strip.
//
// These are the nine that ship. Anything you compose yourself is stored in
// the config and served by GlyphEvents, which is the only one of the two
// that knows about settings.
Singleton {
    id: root

    readonly property var all: [
        { id: "blink",     label: "Blink",
          hint: "One flash" },
        { id: "double",    label: "Double blink",
          hint: "Two quick flashes, the phone's own default" },
        { id: "triple",    label: "Triple blink",
          hint: "Three, for something you should not miss" },
        { id: "heartbeat", label: "Heartbeat",
          hint: "A strong beat and a weak one, then a rest" },
        { id: "strobe",    label: "Strobe",
          hint: "Five fast flashes, urgent" },
        { id: "pulse",     label: "Pulse",
          hint: "Breathes up and down once" },
        { id: "fill",      label: "Fill",
          hint: "Rises through the zones, then out" },
        { id: "chase",     label: "Chase",
          hint: "A single point running the length of it" },
        { id: "flash",     label: "Long flash",
          hint: "On, held, off" }
    ]

    function label(id: string): string {
        return (root.all.find(p => p.id === id)?.label) ?? id;
    }

    function has(id: string): bool {
        return root.all.some(p => p.id === id);
    }

    // How long a whole pattern lasts, so the caller can stop watching.
    function duration(id: string): int {
        return root.steps(id).reduce((t, s) => t + s.ms, 0);
    }

    function steps(id: string): var {
        const on  = (ms, v) => ({ ms: ms, v: v ?? 1, k: "level" });
        const off = ms => ({ ms: ms, v: 0, k: "level" });

        switch (id) {
        case "blink":
            return [on(140), off(260)];

        case "double":
            return [on(120), off(110), on(120), off(420)];

        case "triple":
            return [on(100), off(90), on(100), off(90), on(100), off(420)];

        case "heartbeat":
            // The weak beat is a partial fill rather than a dimmer one:
            // these surfaces have three brightness steps, not a hundred,
            // so a quieter beat has to be a smaller one.
            return [on(130), off(90), on(110, 0.5), off(620)];

        case "strobe":
            return [on(70), off(70), on(70), off(70), on(70),
                    off(70), on(70), off(70), on(70), off(340)];

        case "pulse": {
            // Sampled rather than eased: the step player holds a value for
            // a duration, so a curve is a series of held values. Sixteen
            // is enough that the eye reads it as smooth.
            const out = [];
            const n = 16;
            for (let i = 0; i <= n; i++)
                out.push(on(34, Math.sin(Math.PI * i / n)));
            out.push(off(300));
            return out;
        }

        case "fill": {
            const out = [];
            const n = 12;
            for (let i = 1; i <= n; i++)
                out.push(on(38, i / n));
            out.push(on(160, 1));
            out.push(off(260));
            return out;
        }

        case "chase": {
            const out = [];
            const n = 18;
            for (let i = 0; i < n; i++)
                out.push({ ms: 40, v: i / (n - 1), k: "point" });
            out.push(off(280));
            return out;
        }

        case "flash":
            return [on(520), off(200)];
        }
        return [on(140), off(260)];
    }
}
