pragma Singleton

import QtQuick
import Quickshell
import ".."
import "../services"

// One button for do not disturb, the screen staying awake, and the
// Glyph going dark - the phone's own idea of a focus mode, bundled the
// same way here rather than three separate things to remember to flip
// back afterwards.
//
// Each one is held only if Focus is the thing that turned it on: a DND
// you had already switched on yourself stays on when Focus ends, the
// same restraint NightLight's own schedule already uses around DND for
// the same reason.
Singleton {
    id: root

    property bool active: false
    property bool dndHeld: false
    property bool caffeineHeld: false
    property string glyphHeld: ""

    function toggle(): void {
        if (root.active)
            root.stop();
        else
            root.start();
    }

    function start(): void {
        if (root.active)
            return;
        root.active = true;

        if (!Notifs.doNotDisturb) {
            Notifs.doNotDisturb = true;
            root.dndHeld = true;
        }
        if (!Idle.inhibited) {
            Idle.toggle();
            root.caffeineHeld = true;
        }
        const g = Config.activeGlyph();
        if (g !== "") {
            Config.enableGlyph(g, false);
            root.glyphHeld = g;
        }
    }

    function stop(): void {
        if (!root.active)
            return;
        root.active = false;

        if (root.dndHeld) {
            Notifs.doNotDisturb = false;
            root.dndHeld = false;
        }
        if (root.caffeineHeld) {
            Idle.toggle();
            root.caffeineHeld = false;
        }
        if (root.glyphHeld !== "") {
            Config.enableGlyph(root.glyphHeld, true);
            root.glyphHeld = "";
        }
    }
}
