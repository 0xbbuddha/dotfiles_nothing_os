pragma Singleton

import QtQuick
import Quickshell
import ".."

// Google Lens image search on a screen selection.
//
// The selection goes through the shell's own region picker, the one the
// screenshots already use, and not through slurp. slurp wants a pointer
// grab, the launcher this is started from is a layer surface already
// holding one, and slurp never got it: no crosshair appeared and the
// process sat there forever, which is why the button stayed dimmed until
// the shell was reloaded. Reusing the picker removes the contest instead
// of timing around it.
//
// The upstream rice this borrows from does the same thing: its keybind
// reads `qsIsAlive || pidof slurp || snip_to_search.sh`, so the script is
// only ever the fallback for when the shell is not running. Ours is
// scripts/lens.sh, kept for the same reason and used by nothing here.
//
// The crop is uploaded to a third-party host for a public URL: that is
// the cost of the feature, and it is disclosed in use.
Singleton {
    id: root

    // No flag of our own to leave stuck: the picker owns the lifecycle,
    // including cancellation.
    readonly property bool busy:
        (Shot.busy || Shot.picking) && Shot.pendingAction === "lens"

    // Let the panel that started this disappear before the pre-grab, or
    // it is baked into the frozen image the picker then shows you.
    // modules/Screenshot.qml waits exactly this long, for the same reason.
    Timer {
        id: afterClose
        interval: 220
        onTriggered: Shot.capture("region", "lens")
    }

    function search(): void {
        afterClose.restart();
    }
}
