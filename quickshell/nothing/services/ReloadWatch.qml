pragma Singleton

import QtQuick
import Quickshell

// A reload that fails does so in silence otherwise: the old process
// keeps running, looks exactly like the new one, and the only sign
// anything broke is in a log file nobody is tailing. Quickshell's own
// reloadFailed carries the real QML error, so showing it beats sending
// someone to grep for it.
Singleton {
    id: root

    property bool shown: false
    property string message: ""

    function dismiss(): void { root.shown = false; }
    function retry(): void { Quickshell.reload(true); }

    Connections {
        target: Quickshell
        function onReloadFailed(errorString: string): void {
            root.message = errorString;
            root.shown = true;
        }
        function onReloadCompleted(): void { root.shown = false; }
    }
}
