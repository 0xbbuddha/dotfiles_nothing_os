pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Mouse, touchpad and keyboard: the input block of Hyprland's config,
// reachable from Settings instead of from a text editor.
//
// Written the way WindowLayout writes layout.lua: applied to the running
// compositor with `hyprctl eval`, and kept in ~/.config/hypr/input.lua,
// which hypr/hyprland/general.lua reads after its own input block.
// custom.lua is read after that, so anything you set there still wins;
// the page cannot see it and says so.
//
// The file does not exist until something on the page is changed, so a
// machine that never opens it keeps exactly the input it had. "Back to
// defaults" deletes the overrides by writing the rice's own values back.
// The keyboard layout is not here: general.lua detects it, and a wrong
// layout from a settings page is a hard thing to type your way out of.
Singleton {
    id: root

    readonly property string savePath:
        (Quickshell.env("HOME") ?? "") + "/.config/hypr/input.lua"

    // What hyprctl eval said when it did not say "ok", for the page.
    property string error: ""

    function luaBool(b: bool): string { return b ? "true" : "false"; }

    // Only names Hyprland documents for `input` and `input:touchpad`.
    // accel_profile "" is libinput's own default (adaptive on most mice).
    readonly property string settingsLua: `hl.config({
    input = {
        sensitivity = ${Number(Config.inputSensitivity).toFixed(2)},
        accel_profile = "${Config.inputAccel === "flat" || Config.inputAccel === "adaptive" ? Config.inputAccel : ""}",
        natural_scroll = ${root.luaBool(Config.inputNaturalScroll)},
        follow_mouse = ${Config.inputFollowMouse ? 1 : 0},
        repeat_rate = ${Math.round(Config.inputRepeatRate)},
        repeat_delay = ${Math.round(Config.inputRepeatDelay)},
        numlock_by_default = ${root.luaBool(Config.inputNumlock)},
        touchpad = {
            natural_scroll = ${root.luaBool(Config.touchpadNaturalScroll)},
            disable_while_typing = ${root.luaBool(Config.touchpadDisableTyping)},
            scroll_factor = ${Number(Config.touchpadScrollFactor).toFixed(2)},
        },
    },
})`

    readonly property string saveText:
        "-- Written by the Nothing shell (Settings > Input).\n"
        + "-- Rewritten whenever that page changes, so edits here are lost:\n"
        + "-- put your own input settings in custom.lua, which is read later.\n\n"
        + root.settingsLua + "\n"

    readonly property string chunk:
        "(function() " + root.settingsLua + " return \"ok\" end)()"

    property string savedText: ""
    readonly property bool written: root.savedText.indexOf("hl.config") >= 0

    // Called by the page after it has changed a Config value. Debounced:
    // a slider drag is one eval, not twenty.
    function apply(): void {
        later.restart();
    }

    Timer {
        id: later
        interval: 250
        onTriggered: {
            applier.running = false;
            applier.command = ["hyprctl", "eval", root.chunk];
            applier.running = true;
            keeper.setText(root.saveText);
        }
    }

    NProcess {
        id: applier
        label: "input"
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.error = (t === "" || t === "ok") ? "" : t;
                if (root.error !== "")
                    console.warn("input: " + root.error);
            }
        }
    }

    // The rice's own values from general.lua, and Hyprland's for the rest.
    function reset(): void {
        Config.inputSensitivity = 0;
        Config.inputAccel = "";
        Config.inputNaturalScroll = false;
        Config.inputFollowMouse = true;
        Config.inputRepeatRate = 25;
        Config.inputRepeatDelay = 600;
        Config.inputNumlock = false;
        Config.touchpadNaturalScroll = true;
        Config.touchpadDisableTyping = true;
        Config.touchpadScrollFactor = 0.5;
        Config.save();
        root.apply();
    }

    FileView {
        id: keeper
        path: root.savePath
        // Missing until the page is first used: not a fault.
        printErrors: false
        onLoaded: root.savedText = keeper.text()
        onSaved: root.savedText = keeper.text()
    }
}
