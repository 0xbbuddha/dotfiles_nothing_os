pragma Singleton

import QtQuick
import Quickshell

// What WallpaperPopup shows, and for how long. Split from Wallpapers
// itself: that singleton answers "what wallpaper is this", not "was it
// just changed and does anyone need telling".
Singleton {
    id: root

    property bool shown: false
    property string label: ""
    property string thumb: ""

    function dismiss(): void {
        root.shown = false;
        hide.stop();
    }

    function announce(label: string, thumb: string): void {
        root.label = label;
        root.thumb = thumb;
        root.shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 2600
        onTriggered: root.shown = false
    }
}
