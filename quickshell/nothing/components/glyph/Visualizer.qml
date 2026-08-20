import QtQuick
import "../../services"
import "draw.js" as D

// Twenty-five columns, one per cava bar. The process only runs while
// this toy is shown: see Cava.listening.
QtObject {
    id: root

    readonly property int tick: 33
    signal dirty()

    function render(f: var): void {
        if (!Cava.available) {
            D.smallCentered(f, 10, "CAVA", 1, true);
            return;
        }
        D.bars(f, Cava.values, 1, false);
    }
}
