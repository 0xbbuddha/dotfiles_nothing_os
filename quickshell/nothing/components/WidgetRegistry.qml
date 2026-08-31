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

    // Nothing ships a reduced version of most widgets beside the full one:
    // the same widget with fewer things on it. Marked here rather than
    // built as a second component, so the two can never drift apart.
    function isSimple(id: string): bool { return meta(id)?.simple === true; }

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
        { id: "clockDigitalSimple", label: "Digital, simple", icon: "󰥔",
          hint: "The same, without the seconds",       group: "Time",
          simple: true, height: Theme.px(78) },
        { id: "clockLight",   label: "Light",         icon: "󰔛",
          hint: "Inter at its thinnest",               group: "Time",
          height: Theme.px(78) },
        { id: "clockAnalog",  label: "Dial, ticks",   icon: "󰅐",
          hint: "Sixty marks and two hands",           group: "Clock",
          size: "small", height: root.smallWidth },
        { id: "clockScale",   label: "Dial, scale",   icon: "󰀠",
          hint: "The same face, hairline hands",       group: "Clock",
          size: "small", height: root.smallWidth },
        { id: "clockDial",    label: "Dial, dots",    icon: "󰦖",
          hint: "Twelve dots, red minute hand",        group: "Clock",
          size: "small", height: root.smallWidth },
        { id: "worldClock",   label: "World clock",   icon: "󰖟",
          hint: "Four cities and their times",         group: "Clock",
          height: Theme.px(150) },
        { id: "worldClockSimple", label: "World, simple", icon: "󰖟",
          hint: "The four times, without the city names", group: "Clock",
          simple: true, height: Theme.px(150) },
        { id: "worldClockPair", label: "World, two",  icon: "󰦖",
          hint: "Two cities, square",                  group: "Clock",
          size: "small", height: root.smallWidth },
        { id: "worldClockOne", label: "World, one",   icon: "󰅐",
          hint: "A single city, square",               group: "Clock",
          size: "small", height: root.smallWidth },

        { id: "date",         label: "Date",          icon: "󰃭",
          hint: "Day number, full date, week",         group: "Date",
          height: Theme.z.cardS },
        { id: "dateSimple",   label: "Date, simple",  icon: "󰃭",
          hint: "The card, without the week number",   group: "Date",
          simple: true, height: Theme.z.cardS },
        { id: "dateCompact",  label: "Date, compact", icon: "󰸗",
          hint: "One line, no week number",            group: "Date",
          height: Theme.px(54) },
        { id: "calendar",     label: "Calendar",      icon: "󰸗",
          hint: "The current month",                   group: "Date",
          height: Theme.px(250) },

        { id: "quickLook",    label: "Quick Look",    icon: "󰥔",
          hint: "The date and the sky on one card",    group: "Quick Look",
          height: Theme.px(176) },
        { id: "quickLookSimple", label: "Quick Look, simple", icon: "󰸗",
          hint: "The same, without the city and range", group: "Quick Look",
          simple: true, height: Theme.px(152) },
        { id: "quickLookBare", label: "Quick Look, bare", icon: "󰄄",
          hint: "No card, straight on the wallpaper",   group: "Quick Look",
          height: Theme.px(56) },

        { id: "weather",      label: "Weather",       icon: "󰖐",
          hint: "Temperature, summary, high and low",  group: "Weather",
          height: Theme.px(124) },
        { id: "weatherSimple", label: "Weather, simple", icon: "󰖐",
          hint: "The card, without high and low",      group: "Weather",
          simple: true, height: Theme.px(124) },
        { id: "weatherSquare", label: "Weather, square", icon: "󰖕",
          hint: "Turns between sky, temperature and range", group: "Weather",
          size: "small", height: root.smallWidth },
        { id: "weatherCompact", label: "Weather, compact", icon: "󰖙",
          hint: "One line: place and temperature",     group: "Weather",
          height: Theme.px(54) },

        { id: "media",        label: "Playing",       icon: "󰎆",
          hint: "Artwork, position and transport",     group: "Media",
          height: Theme.px(124) },
        { id: "mediaSquare",  label: "Playing, square", icon: "󰎈",
          hint: "The cover, edge to edge",             group: "Media",
          size: "small", height: root.smallWidth },
        { id: "mediaList",    label: "Playing, sources", icon: "󰲹",
          hint: "A row per source, two at a time",     group: "Media",
          height: Theme.px(140) },

        { id: "net",          label: "Network",       icon: "󰀂",
          hint: "Down and up, over the last minute",   group: "System",
          height: Theme.px(160) },
        { id: "netSimple",    label: "Network, simple", icon: "󰤨",
          hint: "The two rates, without the trace",    group: "System",
          simple: true, height: Theme.px(104) },

        { id: "system",       label: "System",        icon: "󰻠",
          hint: "CPU, RAM, GPU over the last minute",  group: "System",
          height: Theme.px(190) },
        { id: "systemSimple", label: "System, simple", icon: "󰾆",
          hint: "The gauges, without the byte counts", group: "System",
          simple: true, height: Theme.px(140) },

        { id: "battery",      label: "Battery",       icon: "󰁹",
          hint: "Charge in cells, with time and health", group: "Battery",
          height: Theme.px(160) },
        { id: "batterySimple", label: "Battery, simple", icon: "󰁽",
          hint: "The cells, without watts or health",  group: "Battery",
          simple: true, height: Theme.px(134) },
        { id: "batteryRing",  label: "Battery, ring", icon: "󰂀",
          hint: "Twenty dots, one per five per cent",  group: "Battery",
          size: "small", height: root.smallWidth },

        { id: "countdown",    label: "Countdown",     icon: "󰃭",
          hint: "Days to a date, on one of twelve shapes", group: "Countdown",
          size: "small", height: root.smallWidth },
        { id: "countdownSimple", label: "Countdown, simple", icon: "󰅐",
          hint: "The number alone, without the name",  group: "Countdown",
          simple: true, size: "small", height: root.smallWidth },

        { id: "breathCalm",   label: "Calm",          icon: "󰗎",
          hint: "Six in, six out, no holds",           group: "Breathe",
          size: "small", height: root.smallWidth },
        { id: "breathFocus",  label: "Focus",         icon: "󰋑",
          hint: "Four in, four held, four out, four empty", group: "Breathe",
          size: "small", height: root.smallWidth },
        { id: "breathRelax",  label: "Relax",         icon: "󰂜",
          hint: "Four in, seven held, eight out",      group: "Breathe",
          size: "small", height: root.smallWidth },

        { id: "essential",    label: "Essential",     icon: "󰠮",
          hint: "What is coming up, from Essential Space", group: "Essential",
          height: Theme.px(150) },

        { id: "screenTime",   label: "Screen time",   icon: "󰍹",
          hint: "A face that stops smiling past your limit", group: "System",
          size: "small", height: root.smallWidth },

        { id: "photo",        label: "Photo",         icon: "󰉏",
          hint: "A frame from your pictures",          group: "Photo",
          size: "small", height: root.smallWidth },
        { id: "photoRound",   label: "Photo, round",  icon: "󰧨",
          hint: "The same, as a circle",               group: "Photo",
          size: "small", height: root.smallWidth },
        { id: "photoPad",     label: "Photo, inset",  icon: "󰋩",
          hint: "Held inside the card, not bled to it", group: "Photo",
          size: "small", height: root.smallWidth },
        { id: "photoRoundPad", label: "Photo, round inset", icon: "󰸉",
          hint: "The circle, with the card all round it", group: "Photo",
          size: "small", height: root.smallWidth },
        { id: "photoWide",    label: "Photo, wide",   icon: "󰥶",
          hint: "The full width of the column",        group: "Photo",
          height: Theme.px(150) }
    ]

    // The order groups appear in the launcher. Spelled out rather than
    // derived, so a new widget lands where it belongs instead of wherever
    // the catalogue happened to put it.
    // Digits and dials are two families, not two looks of one. You may
    // well want the hour in numerals and a dial beside it; forcing them
    // into one family would make picking either throw the other away.
    readonly property var groups: ["Time", "Clock", "Date", "Quick Look", "Weather",
                                   "Photo", "Media", "Countdown", "Breathe", "Essential", "Battery", "System"]

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
