pragma Singleton

import QtQuick
import Quickshell
import ".."

// Catalogue of what the control centre can hold.
//
// The same idea as BarRegistry, for the same reason: the panel was two
// hardcoded rows of tiles and a hardcoded row of buttons, so the only say
// the user had was whichever ones happened to hide themselves when their
// service was missing. Here every tile is an entry and two lists in
// Config decide what appears and in what order.
//
// Three catalogues, because the panel has three kinds of slot and they
// are not interchangeable. A tile is a wide pill with a title and a state
// line; a footer button is a 36 by 30 square with nothing but a glyph; a
// section is a whole block that is either there or not.
Singleton {
    id: root

    // ── Tiles ─────────────────────────────────────────────────────────
    // The hint is what the settings page shows under a tile that is not
    // in the panel, so it says what the tile would do rather than what it
    // is: "Toggle the radio, right click for networks" is the answer to
    // the question someone reading that list is actually asking.
    readonly property var tiles: [
        { id: "wifi",      label: "Wi-Fi",        icon: "󰖩",
          hint: "Toggle the radio, right click for networks" },
        { id: "bluetooth", label: "Bluetooth",    icon: "󰂯",
          hint: "Toggle the adapter, right click for devices" },
        { id: "warp",      label: "WARP",         icon: "󰖂",
          hint: "Cloudflare WARP. Hidden without warp-cli" },
        { id: "sound",     label: "Sound",        icon: "󰕾",
          hint: "Mute, right click for outputs and levels" },
        { id: "light",     label: "Light",        icon: "󰃠",
          hint: "Screen brightness. Hidden with no backlight" },
        { id: "notify",    label: "Notifications", icon: "󰂚",
          hint: "Do not disturb, right click for the history" },
        { id: "night",     label: "Night light",  icon: "󰖔",
          hint: "Warm the screen now, whatever the schedule says" },
        { id: "theme",     label: "Light or dark", icon: "󰔎",
          hint: "Flips the whole shell between its two looks" },
        { id: "mic",       label: "Microphone",   icon: "󰍬",
          hint: "Mute the input. Hidden with no microphone" },
        { id: "game",      label: "Game mode",    icon: "󰊗",
          hint: "Animations, blur and shadows off while you play" },
        { id: "record",    label: "Recording",    icon: "󰑊",
          hint: "Start and stop a screen recording" },
        { id: "songrec",   label: "What is this", icon: "󰎈",
          hint: "Listen and name the track. Needs songrec" },
        { id: "voice",     label: "Voice note",   icon: "󱑽",
          hint: "Record straight into Essential Space" },
        { id: "dock",      label: "Dock",         icon: "󱂩",
          hint: "Show or hide the dock" }
    ]

    // ── Footer buttons ────────────────────────────────────────────────
    // Glyph only, so every entry has to be recognisable without a label.
    // That is the whole reason this is a separate list and not a flag on
    // the tiles: half of those need their state line to make sense.
    readonly property var footer: [
        { id: "night",      label: "Night light", icon: "󰖔",
          hint: "Warm the screen" },
        { id: "screenshot", label: "Screenshot",  icon: "󰄀",
          hint: "Opens the capture panel" },
        { id: "displays",   label: "Displays",    icon: "󰍹",
          hint: "Arrangement, resolution and refresh rate" },
        { id: "cheatsheet", label: "Shortcuts",   icon: "󰌌",
          hint: "The keyboard shortcut sheet" },
        { id: "settings",   label: "Settings",    icon: "󰒓",
          hint: "This window" },
        { id: "reload",     label: "Reload",      icon: "󰑐",
          hint: "Restarts the shell without touching the session" },
        { id: "lock",       label: "Lock",        icon: "󰌾",
          hint: "Locks the session now" },
        { id: "power",      label: "Session",     icon: "󰐥",
          hint: "Log out, reboot, shut down" }
    ]

    // ── Sections ──────────────────────────────────────────────────────
    // Blocks rather than controls. Each one is a plain boolean in Config,
    // listed here so the settings page can draw them from one place.
    readonly property var sections: [
        { id: "ccCalendar", label: "Calendar",    icon: "󰸗",
          hint: "The date opens a month view" },
        { id: "ccMedia",    label: "Now playing", icon: "󰎈",
          hint: "Cover, title and transport" },
        { id: "ccUpdates",  label: "Updates",     icon: "󰚰",
          hint: "Pending packages, with an install shortcut" },
        { id: "ccStats",    label: "System",      icon: "󰻠",
          hint: "CPU, memory and GPU gauges" },
        { id: "ccCaffeine", label: "Caffeine",    icon: "󰅶",
          hint: "The sleep inhibitor, above the buttons" }
    ]

    function meta(zone: string, id: string): var {
        const list = zone === "footer" ? root.footer : root.tiles;
        return list.find(t => t.id === id) ?? null;
    }

    function label(zone: string, id: string): string {
        return root.meta(zone, id)?.label ?? id;
    }

    function icon(zone: string, id: string): string {
        return root.meta(zone, id)?.icon ?? "󰄰";
    }

    // Everything in no list at all, for the editor to offer. Computed
    // from the lists rather than stored, so it cannot disagree with them.
    function unplaced(zone: string): var {
        const placed = Config.ccZone(zone);
        const all = zone === "footer" ? root.footer : root.tiles;
        return all.filter(t => placed.indexOf(t.id) < 0);
    }
}
