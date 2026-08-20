pragma Singleton

import QtQuick
import Quickshell

// Catalogue of desktop widgets: used by the render and the settings panel.
Singleton {
    readonly property var all: [
        { id: "date",     label: "Date",        icon: "󰃭", hint: "Day, full date, week" },
        { id: "weather",  label: "Weather",       icon: "󰖐", hint: "Temperature, summary, high and low" },
        { id: "clock",    label: "Clock",     icon: "󰥔", hint: "Large dot-matrix clock" },
        { id: "media",    label: "Playing",     icon: "󰎆", hint: "Artwork and transport" },
        { id: "system",   label: "System",     icon: "󰻠", hint: "CPU, RAM, GPU" },
        { id: "calendar", label: "Calendar",  icon: "󰸗", hint: "Current month" }
    ]

    function meta(id: string): var {
        return all.find(w => w.id === id) ?? null;
    }

    function label(id: string): string { return meta(id)?.label ?? id; }
    function icon(id: string): string { return meta(id)?.icon ?? "󰝦"; }
}
