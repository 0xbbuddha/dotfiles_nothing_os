pragma Singleton

import QtQuick
import Quickshell

// Catalogue of desktop widgets: used by the render and the settings panel.
Singleton {
    // Widths a widget may take, in cells. The cell itself is a fixed size
    // (see Desktop.qml), so the count of columns follows the screen rather
    // than the other way round.
    //
    // A grid that divided the screen into a fixed number of columns was
    // the obvious first idea and the wrong one: three columns of twelve
    // is 456px on a 1920 screen and 936px on a 3840 one, so the same clock
    // would be readable on one monitor and absurd on the next. A fixed
    // cell keeps every widget the size it was drawn to be, and a wider
    // screen simply offers more places to put things.
    readonly property int defaultWidth: 2
    readonly property int minWidth: 1
    readonly property int maxWidth: 4

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
