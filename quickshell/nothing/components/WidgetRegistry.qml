pragma Singleton

import QtQuick
import Quickshell
import ".."

// Catalogue of desktop widgets: the render, the launcher and search all
// read it, hence the singleton.
//
// Two rules here, both learned the hard way.
//
// One: a different look is a different widget, never a setting on an
// existing one. A clock that could switch between a dot matrix and a dial
// changed height underneath the column and shoved its neighbours around.
// Separate entries cannot do that: you add the one you want and the column
// knows its size before it draws anything.
//
// Two: every widget declares a fixed height here. Heights that came from
// the content made the desktop twitch whenever the content changed, a
// second media player or a swap partition appearing being enough.
Singleton {
    id: root

    // How much of the column a widget claims.
    //
    // "wide" takes the full width; "small" takes half of it and is square.
    // A dial is round: stretched across the whole column it sat in a field
    // of empty card, and the shape of the thing was the first casualty.
    // Two smalls fill one row side by side, which is how Nothing sizes its
    // own widgets: a square 2x2 tile or a wide 4x2 one.
    readonly property real wideWidth: Theme.z.widgets
    // Floored, not halved exactly: two halves plus the gap can land a
    // fraction of a pixel over the column, and the Flow would then wrap
    // the second one onto its own row for no visible reason.
    readonly property real smallWidth:
        Math.floor((Theme.z.widgets - Theme.gap) / 2)

    function width(id: string): real {
        return meta(id)?.size === "small" ? root.smallWidth : root.wideWidth;
    }

    function isSmall(id: string): bool { return meta(id)?.size === "small"; }

    readonly property var all: [
        { id: "clock",        label: "Ndot",          icon: "󰥔",
          hint: "The dot-matrix face",                 group: "Time",
          height: Theme.px(78) },
        { id: "clockStack",   label: "Ndot, stacked", icon: "󰃰",
          hint: "Hours over minutes, twice the size",  group: "Time",
          size: "small", height: root.smallWidth },
        { id: "clockBare",    label: "Ndot, bare",    icon: "󰄄",
          hint: "No card, dots on the wallpaper",      group: "Time",
          // Tighter than the carded faces on purpose: with no card there
          // is nothing for padding to sit inside, so the same margin just
          // leaves the digits floating in a gap.
          height: Theme.px(68) },
        { id: "clockDigital", label: "Digital",       icon: "󰄉",
          hint: "Mono numerals, with seconds",         group: "Time",
          height: Theme.px(78) },
        { id: "clockLight",   label: "Light",         icon: "󰔛",
          hint: "Inter at its thinnest",               group: "Time",
          height: Theme.px(78) },
        { id: "clockAnalog",  label: "Dial, ticks",   icon: "󰅐",
          hint: "Sixty marks and two hands",           group: "Clock",
          size: "small", height: root.smallWidth },
        { id: "clockDial",    label: "Dial, dots",    icon: "󰦖",
          hint: "Twelve dots, red minute hand",        group: "Clock",
          size: "small", height: root.smallWidth },

        { id: "date",         label: "Date",          icon: "󰃭",
          hint: "Day number, full date, week",         group: "Date",
          height: Theme.z.cardS },
        { id: "dateCompact",  label: "Date, compact", icon: "󰸗",
          hint: "One line, no week number",            group: "Date",
          height: Theme.px(54) },
        { id: "calendar",     label: "Calendar",      icon: "󰸗",
          hint: "The current month",                   group: "Date",
          height: Theme.px(250) },

        { id: "weather",      label: "Weather",       icon: "󰖐",
          hint: "Temperature, summary, high and low",  group: "Weather",
          height: Theme.px(124) },
        { id: "weatherCompact", label: "Weather, compact", icon: "󰖙",
          hint: "One line: place and temperature",     group: "Weather",
          height: Theme.px(54) },

        { id: "media",        label: "Playing",       icon: "󰎆",
          hint: "Artwork, position and transport",     group: "Media",
          height: Theme.px(124) },
        { id: "mediaList",    label: "Playing, sources", icon: "󰲹",
          hint: "A row per source, two at a time",     group: "Media",
          height: Theme.px(140) },

        { id: "system",       label: "System",        icon: "󰻠",
          hint: "CPU, RAM, GPU over the last minute",  group: "System",
          height: Theme.px(190) }
    ]

    // The order groups appear in the launcher. Spelled out rather than
    // derived, so a new widget lands where it belongs instead of wherever
    // the catalogue happened to put it.
    // Digits and dials are two families, not two looks of one. You may
    // well want the hour in numerals and a dial beside it; forcing them
    // into one family would make picking either throw the other away.
    readonly property var groups: ["Time", "Clock", "Date", "Weather", "Media", "System"]

    function meta(id: string): var {
        return all.find(w => w.id === id) ?? null;
    }

    function label(id: string): string { return meta(id)?.label ?? id; }
    function icon(id: string): string { return meta(id)?.icon ?? "󰝦"; }
    function hint(id: string): string { return meta(id)?.hint ?? ""; }

    // Zero for an unknown id, so a widget left over in a config from an
    // older version takes no room rather than half a screen.
    function height(id: string): real { return meta(id)?.height ?? 0; }

    function group(id: string): string { return meta(id)?.group ?? ""; }

    function inGroup(name: string): var {
        return all.filter(w => w.group === name);
    }
}
