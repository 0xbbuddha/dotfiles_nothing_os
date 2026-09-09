pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The window border, following the accent.
//
// Hyprland draws the frame around the focused window and the shell draws
// everything inside it, and until now they did not agree: the border was
// "rgba(d71921ff)" written into hypr/hyprland/variables.lua, so picking a
// new accent in settings recoloured the whole shell and left the window
// frame the old red. The one piece of the desktop the compositor owns was
// the one piece that did not follow.
//
// Same method as the layout service: applied to the running compositor
// with `hyprctl eval`, and left in a small Lua file that
// hypr/hyprland/general.lua reads back at startup, so it survives a
// restart. `hyprctl keyword` is not an option against a Lua config.
Singleton {
    id: root

    readonly property string savePath:
        (Quickshell.env("HOME") ?? "") + "/.config/hypr/accent.lua"

    // Hyprland wants rgba(rrggbbaa). Config.accent is "#rrggbb", and a QML
    // colour stringifies as "#aarrggbb" with the alpha in front, so both
    // shapes have to be handled or the border silently keeps its old
    // value: an unparseable colour is not an error, it is ignored.
    function hyprColour(c: var): string {
        const hex = String(c).replace("#", "").toLowerCase();
        if (hex.length === 8)
            return "rgba(" + hex.slice(2) + hex.slice(0, 2) + ")";
        if (hex.length === 6)
            return "rgba(" + hex + "ff)";
        return "rgba(d71921ff)";
    }

    readonly property string activeBorder: root.hyprColour(Config.accent)

    // The inactive frame follows the theme rather than staying dark: on
    // the light theme a near-black hairline around every window was the
    // one thing that never turned over. Theme.c.outline is what the shell
    // draws its own hairlines with, so the two now match by construction.
    readonly property string inactiveBorder: root.hyprColour(Theme.c.outline)

    readonly property string settingsLua: `hl.config({
    general = {
        col = {
            active_border = "${root.activeBorder}",
            inactive_border = "${root.inactiveBorder}",
        },
    },
})`

    readonly property string saveText:
        "-- Written by the Nothing shell (Settings > Appearance > Accent).\n"
        + "-- Rewritten whenever the accent or the theme changes, so edits\n"
        + "-- here are lost. Read at the end of hypr/hyprland/general.lua.\n\n"
        + root.settingsLua + "\n"

    // hyprctl eval wraps its argument in `return`, so the chunk has to be
    // an expression.
    readonly property string chunk:
        "(function() " + root.settingsLua + " return \"ok\" end)()"

    property string savedText: ""
    readonly property bool saved: root.savedText === root.saveText

    function apply(): void {
        applier.running = false;
        applier.command = ["hyprctl", "eval", root.chunk];
        applier.running = true;
        keeper.setText(root.saveText);
    }

    NProcess { id: applier; label: "accent" }

    FileView {
        id: keeper
        path: root.savePath
        // Missing until the accent is first changed, which is not a fault
        // worth printing.
        printErrors: false
        onLoaded: root.savedText = keeper.text()
        onSaved: root.savedText = keeper.text()
    }

    // Debounced: the accent swatches are a row of buttons and the theme is
    // a toggle, but a colour picker dragging through a gradient would
    // otherwise spawn one hyprctl per frame.
    Timer {
        id: settle
        interval: 120
        onTriggered: root.apply()
    }

    Connections {
        target: Config
        function onAccentChanged() { settle.restart(); }
        function onThemeChanged() { settle.restart(); }
    }

    // On startup Hyprland has already read accent.lua, so there is nothing
    // to do unless the file disagrees with the settings: a fresh install
    // that has never written one, or a config copied from another machine.
    Component.onCompleted: catchUp.start()

    Timer {
        id: catchUp
        interval: 1500
        onTriggered: if (Config.ready && !root.saved) root.apply()
    }
}
