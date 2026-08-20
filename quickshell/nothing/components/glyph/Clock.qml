import QtQuick
import "../../services"
import "draw.js" as D

// Hours and minutes, two lines of 5x7 digits. That is the reason for
// 25x25: at 13x13 these glyphs do not fit.
QtObject {
    id: root

    readonly property int tick: 1000
    signal dirty()

    property var _clock: Connections {
        target: Time
        function onNowChanged(): void { root.dirty(); }
    }

    function render(f: var): void {
        const d = Time.now;
        const hh = String(d.getHours()).padStart(2, "0");
        const mm = String(d.getMinutes()).padStart(2, "0");
        D.bigCentered(f, 5, hh, 1, false);
        D.bigCentered(f, 13, mm, 1, false);
    }
}
