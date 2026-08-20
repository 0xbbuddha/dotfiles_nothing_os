pragma Singleton

import QtQuick
import Quickshell

// Catalogue of widgets that can be placed on the game canvas.
Singleton {
    readonly property var all: [
        { id: "resources", label: "System",     short: "SYS",   icon: "󰻠",
          hint: "CPU, RAM, GPU and temperatures", w: 240, h: 132 },
        { id: "fps",       label: "FPS cap",    short: "FPS",   icon: "󰓅",
          hint: "Cap frames via MangoHud",        w: 240, h: 108 },
        { id: "recorder",  label: "Recorder",   short: "REC",   icon: "󰑊",
          hint: "Screen, region, with or without audio", w: 252, h: 124 },
        { id: "mixer",     label: "Mixer",      short: "VOL",   icon: "󰕾",
          hint: "Per-application volume",         w: 280, h: 196 },
        { id: "notes",     label: "Notes",      short: "PAD",   icon: "󰠮",
          hint: "Codes, macros, reminders",       w: 260, h: 196 },
        { id: "clock",     label: "Clock",      short: "TIME",  icon: "󰥔",
          hint: "Dot-matrix time",                w: 200, h: 88 },
        { id: "image",     label: "Reference",  short: "REF",   icon: "󰋩",
          hint: "Pinned screenshot or build order", w: 280, h: 200 }
    ]

    function meta(id: string): var { return all.find(w => w.id === id) ?? null; }
}
