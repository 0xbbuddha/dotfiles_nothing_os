pragma Singleton

import QtQuick
import Quickshell
import ".."

// Catalogue of what can sit in the bar, and where.
//
// The bar used to be three hardcoded islands, and the only say the user
// had was eight booleans that hid things where they already were. Here
// every element is an entry, and the three zone lists in Config decide
// what appears, in what order, and in which island. Moving the clock to
// the right is a list edit rather than a patch.
//
// A registry rather than a property per element for the same reason the
// desktop widgets have one: the bar, the settings page and search all
// need the same list, and three copies of it drift.
Singleton {
    id: root

    readonly property var zones: ["left", "centre", "right"]

    function zoneLabel(zone: string): string {
        switch (zone) {
        case "left":   return "Left";
        case "centre": return "Centre";
        default:       return "Right";
        }
    }

    // `wide` marks the elements that take real width rather than sitting
    // in an icon's worth of space. The centre island is measured against
    // the two side islands to stay centred, so it matters there.
    readonly property var all: [
        { id: "workspaces", label: "Workspaces",  icon: "󰕰", zone: "left",
          hint: "The dots, or numerals, for this monitor", wide: true },
        { id: "media",      label: "Now playing", icon: "󰎈", zone: "left",
          hint: "Title and play state, click to pause",    wide: true },
        { id: "window",     label: "Window",      icon: "󰖯", zone: "left",
          hint: "Title of the focused window",             wide: true },

        { id: "apps",       label: "Essential Apps", icon: "󰀻", zone: "centre",
          hint: "The dot grid that opens the apps shelf" },
        { id: "clock",      label: "Clock",       icon: "󰥔", zone: "centre",
          hint: "Time, and the date on hover",             wide: true },
        { id: "essential",  label: "Essential Key", icon: "󰋼", zone: "centre",
          hint: "The capture key, held to record" },

        { id: "tray",       label: "System tray", icon: "󰅢", zone: "right",
          hint: "Icons from background applications",      wide: true },
        { id: "net",        label: "Network",     icon: "󰖩", zone: "right",
          hint: "Wi-Fi or ethernet, click for the panel" },
        { id: "bluetooth",  label: "Bluetooth",   icon: "󰂯", zone: "right",
          hint: "Adapter state and connected devices" },
        { id: "cpu",        label: "CPU",         icon: "󰻠", zone: "right",
          hint: "Load, as a percentage" },
        { id: "ram",        label: "Memory",      icon: "󰍛", zone: "right",
          hint: "Used memory, as a percentage" },
        { id: "gpu",        label: "GPU",         icon: "󰢮", zone: "right",
          hint: "Load. Hidden when no GPU reports one" },
        { id: "temp",       label: "Temperature", icon: "󰔐", zone: "right",
          hint: "CPU package temperature" },
        { id: "updates",    label: "Updates",     icon: "󰚰", zone: "right",
          hint: "Pending packages. Hidden when there are none" },
        { id: "mic",        label: "Microphone",  icon: "󰍬", zone: "right",
          hint: "Mute state, click to toggle" },
        { id: "volume",     label: "Volume",      icon: "󰕾", zone: "right",
          hint: "Output level, scroll to change" },
        { id: "battery",    label: "Battery",     icon: "󰁹", zone: "right",
          hint: "Charge and state. Hidden on a desktop" },
        { id: "notifications", label: "Notifications", icon: "󰂚", zone: "right",
          hint: "The bell, with the unread count" },
        { id: "privacy",    label: "Privacy",     icon: "󰄀", zone: "right",
          hint: "Shown while the mic, camera or screen is in use" },
        { id: "recording",  label: "Recording",   icon: "󰑊", zone: "right",
          hint: "Shown while a screen recording is running" }
    ]

    function meta(id: string): var {
        return root.all.find(w => w.id === id) ?? null;
    }

    function label(id: string): string { return root.meta(id)?.label ?? id; }
    function icon(id: string): string { return root.meta(id)?.icon ?? "󰄰"; }
    function isWide(id: string): bool { return root.meta(id)?.wide === true; }

    // Everything that is in no zone at all, for the settings page to
    // offer. Computed from the three lists rather than stored, so it
    // cannot disagree with them.
    function unplaced(): var {
        // Through barZone, which returns real arrays: a JsonAdapter list
        // has no concat, and calling one silently yields nothing.
        const placed = Config.barZone("left")
            .concat(Config.barZone("centre"), Config.barZone("right"));
        return root.all.filter(w => placed.indexOf(w.id) < 0);
    }
}
