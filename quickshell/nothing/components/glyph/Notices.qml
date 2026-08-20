import QtQuick
import "../.."
import "../../services"
import "draw.js" as D

// Unread notification count. Full disc when the queue is empty:
// the Glyph Matrix does not keep showing a zero; it almost turns off.
QtObject {
    id: root

    readonly property int tick: 0
    signal dirty()

    function render(f: var): void {
        const n = Notifs.unread;
        if (n <= 0) {
            D.disc(f, D.center(f), D.center(f), 11, 0.22, false);
            return;
        }
        D.circle(f, 10.5, 1.6, 0.35, true);
        const s = n > 99 ? "99" : String(n);
        if (s.length === 1)
            D.bigCentered(f, 9, s, 1, true);
        else
            D.smallCentered(f, 10, s, 1, true);
    }

    function tap(): void {
        GlobalState.notifCenterOpen = true;
        Notifs.markAllSeen();
        root.dirty();
    }

    property var _notifs: Connections {
        target: Notifs
        function onUnreadChanged(): void { root.dirty(); }
    }
}
