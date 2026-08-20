pragma Singleton

import QtQuick
import Quickshell

// Shortcut catalogue, shown by the cheatsheet (SUPER + /).
// Do not name this singleton "Keys": it would shadow the attached
// Keys.onEscapePressed property in every file that imports it.
// Kept by hand rather than read from "hyprctl binds", which only
// returns "__lua 444" as the action and would be unreadable.
Singleton {
    readonly property var groups: [
        {
            title: "Panels",
            icon: "󰕰",
            items: [
                { keys: ["SUPER"],          label: "Essential Search" },
                { keys: ["SUPER", "R"],     label: "Essential Search" },
                { keys: ["SUPER", "Tab"],   label: "Essential Search" },
                { keys: ["SUPER", "V"],     label: "Clipboard" },
                { keys: ["SUPER", "N"],     label: "Control centre" },
                { keys: ["SUPER", "B"],     label: "Notifications" },
                { keys: ["SUPER", "G"],     label: "Game bar" },
                { keys: ["SUPER", "I"],     label: "Settings" },
                { keys: ["SUPER", "A"],     label: "Essential Space" },
                { keys: ["SUPER", "/"],     label: "This cheatsheet" },
                { keys: ["CTRL", "ALT", "Del"], label: "Session menu" }
            ]
        },
        {
            title: "Search (SUPER)",
            icon: "󰍉",
            items: [
                { keys: [">"], label: "Applications only" },
                { keys: [";"], label: "Clipboard" },
                { keys: [":"], label: "Emoji" },
                { keys: ["="], label: "Calculator (qalc)" },
                { keys: ["$"], label: "Run a command" },
                { keys: ["?"], label: "Search the web" },
                { keys: ["/"], label: "Shell actions" },
                { keys: ["CTRL", "Enter"], label: "Ask Gemini" }
            ]
        },
        {
            title: "Applications",
            icon: "󰀻",
            items: [
                { keys: ["SUPER", "Enter"], label: "Terminal" },
                { keys: ["SUPER", "T"],      label: "Terminal" },
                { keys: ["SUPER", "E"],      label: "Files" },
                { keys: ["SUPER", "W"],      label: "Browser" },
                { keys: ["SUPER", "C"],      label: "Code editor" },
                { keys: ["SUPER", "X"],      label: "Text editor" },
                { keys: ["CTRL", "SUPER", "V"], label: "Audio mixer" }
            ]
        },
        {
            title: "Windows",
            icon: "󰖯",
            items: [
                { keys: ["SUPER", "Q"],      label: "Close" },
                { keys: ["SUPER", "SHIFT", "F"], label: "Maximise" },
                { keys: ["SUPER", "D"],      label: "Vesktop" },
                { keys: ["SUPER", "F"],      label: "Fullscreen" },
                { keys: ["SUPER", "P"],      label: "Pin" },
                { keys: ["SUPER", "J"],      label: "Toggle split" },
                { keys: ["SUPER", "ALT", "Space"], label: "Floating" },
                { keys: ["SUPER", "arrows"], label: "Move focus" },
                { keys: ["SUPER", "SHIFT", "arrows"], label: "Move the window" },
                { keys: ["SUPER", "click"],   label: "Move with the mouse" },
                { keys: ["SUPER", "right click"], label: "Resize" }
            ]
        },
        {
            title: "Workspaces",
            icon: "󰧨",
            items: [
                { keys: ["SUPER"],               label: "See all 10 workspaces" },
                { keys: ["SUPER", "1..0"],       label: "Go to workspace" },
                { keys: ["SUPER", "ALT", "1..0"], label: "Send the window there" },
                { keys: ["SUPER", "scroll"],     label: "Next or previous workspace" },
                { keys: ["CTRL", "SUPER", "←→"], label: "Relative workspace" },
                { keys: ["SUPER", "S"],          label: "Scratchpad" },
                { keys: ["SUPER", "ALT", "S"],   label: "Send the window there" }
            ]
        },
        {
            title: "Capture",
            icon: "󰄀",
            items: [
                { keys: ["SUPER", "SHIFT", "S"],  label: "Capture: click, highlight or drag" },
                { keys: ["CTRL", "SHIFT", "S"],   label: "Capture a selection" },
                { keys: ["Print"],              label: "Capture the screen" },
                { keys: ["CTRL", "Print"],      label: "Capture to a file" },
                { keys: ["SUPER", "SHIFT", "X"],  label: "OCR a selection" },
                { keys: ["SUPER", "SHIFT", "C"],  label: "Colour picker" },
                { keys: ["key"],                label: "Essential Key · capture" },
                { keys: ["key", "×2"],          label: "Essential Key · open" },
                { keys: ["hold key"],           label: "Essential Key · voice note" },
                { keys: ["SUPER", "SHIFT", "R"],  label: "Record a region" },
                { keys: ["CTRL", "ALT", "R"],   label: "Record the screen" },
                { keys: ["SUPER", "SHIFT", "ALT", "R"], label: "Record with audio" }
            ]
        },
        {
            title: "Game",
            icon: "󰊴",
            items: [
                { keys: ["SUPER", "G"],        label: "Game bar" },
                { keys: ["SUPER", "ALT", "G"], label: "Toggle game mode" },
                { keys: ["SUPER", "ALT", "X"], label: "Toggle crosshair" }
            ]
        },
        {
            title: "System",
            icon: "󰒓",
            items: [
                { keys: ["SUPER", "L"],       label: "Lock" },
                { keys: ["SUPER", "SHIFT", "L"], label: "Suspend" },
                { keys: ["SUPER", "Esc"],   label: "Session menu" },
                { keys: ["SUPER", "-", "="],  label: "Screen zoom" },
                { keys: ["SUPER", "SHIFT", "P"], label: "Play or pause" },
                { keys: ["SUPER", "SHIFT", "N"], label: "Next track" },
                { keys: ["SUPER", "SHIFT", "B"], label: "Previous track" },
                { keys: ["SUPER", "SHIFT", "M"], label: "Mute" }
            ]
        }
    ]

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "") return groups;
        return groups
            .map(g => ({
                title: g.title,
                icon: g.icon,
                items: g.items.filter(i =>
                    i.label.toLowerCase().includes(q)
                    || i.keys.join(" ").toLowerCase().includes(q))
            }))
            .filter(g => g.items.length > 0);
    }
}
