pragma Singleton

import QtQuick
import Quickshell

// Colour arithmetic, so a colour is never written down twice.
//
// Every function here exists because the shell already needed it and had
// it hand-written at the call site, which is where a theme bug came from:
// a subtitle painted Qt.rgba(0, 0, 0, 0.5) read correctly on a dark shell
// only because the surface under it happened to be white there, and turned
// black on black the moment the theme went light.
Singleton {
    id: root

    // Same colour, different opacity. The point is that the hue comes from
    // a theme token rather than being retyped as literal channels.
    function applyAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Relative luminance, WCAG 2.1. Qt's colour channels are already
    // 0 to 1 and sRGB encoded, which is what this expects.
    function luminance(c: color): real {
        const f = v => v <= 0.03928 ? v / 12.92
                                    : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    // WCAG contrast ratio, 1 (identical) to 21 (black on white).
    function contrast(a: color, b: color): real {
        const la = root.luminance(a);
        const lb = root.luminance(b);
        const hi = Math.max(la, lb);
        const lo = Math.min(la, lb);
        return (hi + 0.05) / (lo + 0.05);
    }

    function isDark(c: color): bool {
        return root.luminance(c) < 0.5;
    }

    // Whichever of the shell's two ink colours reads better on `bg`.
    //
    // The accent is user-chosen and the presets include white, so a
    // foreground that simply followed the theme went invisible: white ink
    // on a white accent is a contrast of exactly 1.00, and the switch
    // looked empty whenever it was on.
    function readableOn(bg: color): color {
        return root.contrast(bg, "#ffffff") >= root.contrast(bg, "#0b0b0b")
            ? "#ffffff" : "#0b0b0b";
    }

    // Linear blend, `t` from 0 (a) to 1 (b).
    function mix(a: color, b: color, t: real): color {
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * k,
                       a.g + (b.g - a.g) * k,
                       a.b + (b.b - a.b) * k,
                       a.a + (b.a - a.a) * k);
    }
}
