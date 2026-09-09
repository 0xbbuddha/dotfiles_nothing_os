pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Which layout Hyprland arranges windows with.
//
// Two of them. `tiling` is dwindle, what this rice has always used: a new
// window splits the space and everything on screen gets smaller. Scrolling
// is Hyprland's own scrolling layout, the one niri made people want:
// windows sit side by side on a tape that runs off the screen, and a new
// one is added at its own width rather than taken out of everyone else's.
//
// No plugin. hyprscrolling was a hyprpm plugin until it was merged into
// the compositor in 0.54, so on anything current this is a config value
// and nothing else. `available` is still checked, because a machine on an
// older Hyprland would otherwise be offered a layout that does not exist.
//
// Written the way the display manager writes displays.lua: applied to the
// running compositor with `hyprctl eval`, and left in a small Lua file
// that hypr/hyprland/general.lua reads back at startup. `hyprctl keyword`
// is not an option here, it answers "can't work with non-legacy parsers"
// against a Lua config.
Singleton {
    id: root

    readonly property string savePath:
        (Quickshell.env("HOME") ?? "") + "/.config/hypr/layout.lua"

    // False on a Hyprland too old to have the layout built in. Read once:
    // the compositor is not going to grow a layout while the shell runs.
    property bool available: true
    property bool probed: false

    readonly property bool scrolling:
        root.available && Config.windowLayout === "scrolling"

    // The layout name Hyprland knows, as opposed to the one settings shows.
    readonly property string hyprName: root.scrolling ? "scrolling" : "dwindle"

    // 0 = centre the column, 1 = fit it into view.
    readonly property int fitMethod: Config.scrollFocusFit === "center" ? 0 : 1

    NProcess {
        id: probe
        quiet: true
        running: true
        command: ["sh", "-c",
            "hyprctl getoption scrolling:column_width 2>&1 | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "float: 0.500000" when the layout is there, "no such
                // option" when it is not.
                root.available = text.indexOf("no such option") < 0;
                root.probed = true;
                if (!root.available && Config.windowLayout === "scrolling") {
                    Config.windowLayout = "tiling";
                    Config.save();
                }
            }
        }
    }

    // ── The Lua ───────────────────────────────────────────────────────
    // The scrolling table is written whichever layout is on. It costs
    // nothing in dwindle and it means switching over lands on the settings
    // you already chose rather than on the defaults.
    readonly property string settingsLua: `hl.config({
    general = { layout = "${root.hyprName}" },
    scrolling = {
        column_width = ${Config.scrollColumnWidth.toFixed(3)},
        focus_fit_method = ${root.fitMethod},
        fullscreen_on_one_column = ${Config.scrollFullscreenOne ? "true" : "false"},
        follow_focus = ${Config.scrollFollowFocus ? "true" : "false"},
        direction = "${Config.scrollDirection}",
    },
})`

    readonly property string saveText:
        "-- Written by the Nothing shell (Settings > Interface > Windows).\n"
        + "-- Rewritten whenever that section changes, so edits here are lost.\n"
        + "-- Read at the end of hypr/hyprland/general.lua.\n\n"
        + root.settingsLua + "\n"

    // hyprctl eval wraps its argument in `return`, so the chunk has to be
    // an expression. Same shape the display manager uses.
    readonly property string chunk:
        "(function() " + root.settingsLua + " return \"ok\" end)()"

    property string savedText: ""
    readonly property bool saved: root.savedText === root.saveText

    function apply(): void {
        if (!root.probed)
            return;
        applier.running = false;
        applier.command = ["hyprctl", "eval", root.chunk];
        applier.running = true;
        keeper.setText(root.saveText);
    }

    NProcess { id: applier; label: "layout" }

    FileView {
        id: keeper
        path: root.savePath
        // Missing until the layout is first changed, which is not a fault
        // worth printing.
        printErrors: false
        onLoaded: root.savedText = keeper.text()
        onSaved: root.savedText = keeper.text()
    }

    // Any of the six settings moving rewrites both the compositor and the
    // file. Debounced: dragging the column width slider would otherwise
    // spawn one hyprctl per pixel.
    Timer {
        id: settle
        interval: 120
        onTriggered: root.apply()
    }

    Connections {
        target: Config
        function onWindowLayoutChanged() { settle.restart(); }
        function onScrollColumnWidthChanged() { settle.restart(); }
        function onScrollFocusFitChanged() { settle.restart(); }
        function onScrollDirectionChanged() { settle.restart(); }
        function onScrollFullscreenOneChanged() { settle.restart(); }
        function onScrollFollowFocusChanged() { settle.restart(); }
    }

    // On startup Hyprland has already read layout.lua, so there is nothing
    // to apply unless the file disagrees with the settings: a config
    // copied from another machine, or the file removed by hand.
    Component.onCompleted: catchUp.start()

    Timer {
        id: catchUp
        interval: 1500
        onTriggered: if (root.probed && Config.ready && !root.saved) root.apply()
    }
}
