pragma Singleton

import QtQuick
import Quickshell

// Nothing's own icons.
//
// Essential Search is theirs exactly: the vector drawable read out of
// com.nothing.launcher, path for path. The hexagon it sits in is reused
// below, because Essential Space is that same shape.
//
// Essential Space is that hexagon with Nothing's six-spoke mark punched
// through it. The mark was measured off the icon rather than drawn by eye:
// a 384 pixel render gives a centre disc of radius 19, six bars 48 long
// and 20 thick, their centres 65 out, every 60 degrees. Those numbers are
// scaled here into the viewport the hexagon was authored in.
//
// Essential Apps is the one honest approximation. The only render I had is
// 154 pixels wide, and at that size the spokes of its asterisk merge into
// one blob. Its ellipse and its slash are measured; the asterisk is placed
// from what can be read off it, which is that the mark lies across the
// ellipse rather than standing upright: a bar through the middle, thirty
// degrees off Essential Space's. Drawing it upright, as I did first, put
// two spokes straight through the flat top and bottom of the ellipse.
// Close, and not claimed as extracted.
//
// An icon is a list of parts, painted in order. Most have one: its shapes
// are separate contours in a single string, filled even-odd, so the inner
// ones are holes rather than a second colour on top, which is what lets
// one icon sit on any background.
//
// Nothing X has three, because it is genuinely three-coloured: a bar
// behind, a bar in front, and the red disc on the front bar's end cap.
// A part names a role, never a colour, so the same icon reads on a dark
// dock and on a light panel.
//
// The Arch logo is not Nothing's, obviously. It is here because this is
// the same kind of thing: a mark that belongs to someone, taken from their
// own file rather than traced. It comes from archlinux-logo.svg, minus the
// trademark lettering, which is theirs to place and not mine.
//
// Nothing X was measured off their own 512 pixel store render: two
// identical capsules 359 long and 151 thick crossed at right angles, and
// the disc exactly on the lower cap's centre, 104 out along the bar.
Singleton {
    id: root

    readonly property var icons: ({
        "archLinux": { viewport: 256,
                            parts: [{ role: "on", d: "m127.98 12.07c-10.316 25.309-16.543 41.855-28.031 66.41 7.043 7.4609 15.691 16.156 29.734 25.977-15.098-6.207-25.395-12.445-33.094-18.918-14.703 30.68-37.742 74.391-84.492 158.39 36.746-21.219 65.23-34.293 91.773-39.289-1.1406-4.8945-1.7852-10.195-1.7422-15.734l0.042969-1.1719c0.58203-23.551 12.828-41.645 27.336-40.418 14.508 1.2266 25.781 21.316 25.199 44.867-0.10938 4.4219-0.60938 8.6914-1.4805 12.641 26.258 5.1328 54.438 18.18 90.684 39.105-7.1484-13.156-13.527-25.016-19.621-36.316-9.5938-7.4336-19.605-17.117-40.023-27.594 14.035 3.6406 24.082 7.8516 31.914 12.555-61.941-115.32-66.957-130.66-88.199-180.5z" }] },
        "essentialSearch": { viewport: 72,
                            parts: [{ role: "on", d: "M28.342,4.397C33.08,1.662 38.916,1.662 43.654,4.397L59.842,13.743C64.58,16.479 67.498,21.533 67.498,27.004V45.696C67.498,51.167 64.58,56.222 59.842,58.957L43.654,68.303C38.916,71.038 33.08,71.038 28.342,68.303L12.154,58.957C7.416,56.222 4.498,51.167 4.498,45.696V27.004C4.498,21.533 7.416,16.479 12.154,13.743L28.342,4.397ZM44.852,38.321C44.045,37.855 43.685,36.894 43.837,35.975C43.944,35.331 44,34.669 44,33.995C44,27.367 38.627,21.995 32,21.995C25.373,21.995 20,27.367 20,33.995C20,40.622 25.373,45.995 32,45.995C34.776,45.995 37.332,45.052 39.365,43.469C40.081,42.912 41.065,42.764 41.851,43.218L50.733,48.346C51.689,48.898 52.913,48.571 53.465,47.614L54.336,46.106C54.888,45.149 54.56,43.926 53.604,43.374L44.852,38.321Z M32,34m-10,0a10,10 0,1 1,20 0a10,10 0,1 1,-20 0" }] },
        "essentialSpace": { viewport: 72,
                            parts: [{ role: "on", d: "M28.342,4.397C33.08,1.662 38.916,1.662 43.654,4.397L59.842,13.743C64.58,16.479 67.498,21.533 67.498,27.004V45.696C67.498,51.167 64.58,56.222 59.842,58.957L43.654,68.303C38.916,71.038 33.08,71.038 28.342,68.303L12.154,58.957C7.416,56.222 4.498,51.167 4.498,45.696V27.004C4.498,21.533 7.416,16.479 12.154,13.743L28.342,4.397Z M36.00,30.66a5.34,5.34 0 1,1 0,10.69a5.34,5.34 0 1,1 0,-10.69Z M38.81,21.66A2.81,2.81 0 0,1 33.19,21.66L33.19,13.78A2.81,2.81 0 0,1 38.81,13.78Z M49.83,31.26A2.81,2.81 0 0,1 47.02,26.39L53.84,22.45A2.81,2.81 0 0,1 56.65,27.33Z M47.02,45.61A2.81,2.81 0 0,1 49.83,40.74L56.65,44.67A2.81,2.81 0 0,1 53.84,49.55Z M33.19,50.34A2.81,2.81 0 0,1 38.81,50.34L38.81,58.22A2.81,2.81 0 0,1 33.19,58.22Z M22.17,40.74A2.81,2.81 0 0,1 24.98,45.61L18.16,49.55A2.81,2.81 0 0,1 15.35,44.67Z M24.98,26.39A2.81,2.81 0 0,1 22.17,31.26L15.35,27.33A2.81,2.81 0 0,1 18.16,22.45Z" }] },
        "essentialApps": { viewport: 72,
                            parts: [{ role: "on", d: "M36.00,16.80a32.50,19.20 0 1,1 0,38.40a32.50,19.20 0 1,1 0,-38.40Z M39.76,33.09A1.80,1.80 0 0,1 36.64,31.29L40.64,24.36A1.80,1.80 0 0,1 43.76,26.16Z M40.40,37.80A1.80,1.80 0 0,1 40.40,34.20L48.40,34.20A1.80,1.80 0 0,1 48.40,37.80Z M36.64,40.71A1.80,1.80 0 0,1 39.76,38.91L43.76,45.84A1.80,1.80 0 0,1 40.64,47.64Z M32.24,38.91A1.80,1.80 0 0,1 35.36,40.71L31.36,47.64A1.80,1.80 0 0,1 28.24,45.84Z M31.60,34.20A1.80,1.80 0 0,1 31.60,37.80L23.60,37.80A1.80,1.80 0 0,1 23.60,34.20Z M35.36,31.29A1.80,1.80 0 0,1 32.24,33.09L28.24,26.16A1.80,1.80 0 0,1 31.36,24.36Z M13.37,60.36A1.80,1.80 0 0,1 10.87,57.77L58.63,11.64A1.80,1.80 0 0,1 61.13,14.23Z" }] },
        "nothingLauncher": { viewport: 108,
                            box: { x: 36, y: 30, w: 38, h: 48 },
                            parts: [{ role: "on", d: "M42.5,60L50.5,60A3.5,3.5 0,0 1,54 63.5L54,71.5A3.5,3.5 0,0 1,50.5 75L42.5,75A3.5,3.5 0,0 1,39 71.5L39,63.5A3.5,3.5 0,0 1,42.5 60z M46.5,33L46.5,33A7.5,7.5 0,0 1,54 40.5L54,51.5A7.5,7.5 0,0 1,46.5 59L46.5,59A7.5,7.5 0,0 1,39 51.5L39,40.5A7.5,7.5 0,0 1,46.5 33z M62.5,75a7.5,7.5 0,1 0,0 -15a7.5,7.5 0,1 0,0 15z" }] },
        "nothingX": { viewport: 72,
                            parts: [{ role: "dim", d: "M31.16,66.46A18.12,18.12 0 0,1 5.54,40.84L40.84,5.54A18.12,18.12 0 0,1 66.46,31.16Z" },
                                    { role: "on", d: "M5.54,31.16A18.12,18.12 0 0,1 31.16,5.54L66.46,40.84A18.12,18.12 0 0,1 40.84,66.46Z" },
                                    { role: "accent", d: "M53.65,40.33a13.32,13.32 0 1,1 0,26.64a13.32,13.32 0 1,1 0,-26.64Z" }] }
    })

    function has(id: string): bool {
        return root.icons[id] !== undefined;
    }
}
