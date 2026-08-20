pragma Singleton

import QtQuick
import Quickshell

// Catalogue of Glyph Matrix toys: render, settings and search
// all three use it, hence the singleton.
Singleton {
    readonly property var all: [
        { id: "clock",      label: "Clock",         hint: "Hours and minutes" },
        { id: "battery",    label: "Battery",       hint: "Charge as a ring" },
        { id: "system",     label: "System",        hint: "CPU, RAM and GPU" },
        { id: "notices",    label: "Notifications", hint: "Unread count" },
        { id: "counter",    label: "Counter",       hint: "Nothing's pointless tap" },
        { id: "dice",       label: "Dice",          hint: "Roll one to six" },
        { id: "timer",      label: "Timer",         hint: "Stopwatch and countdown" },
        { id: "pendulum",   label: "Pendulum",      hint: "A swinging trail" },
        { id: "visualizer", label: "Visualizer",    hint: "Twenty-five bars of audio" }
    ]

    readonly property var defaultIds: [
        "clock", "battery", "system", "notices", "counter",
        "dice", "timer", "pendulum", "visualizer"
    ]

    function meta(id: string): var {
        return all.find(t => t.id === id) ?? null;
    }

    function label(id: string): string { return meta(id)?.label ?? id; }
}
