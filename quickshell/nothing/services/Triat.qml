pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Triat (github.com/kerstz/triat), a music player that ships its own bar
// module for this rice: components/bar/TriatBarItem.qml, copied in by its
// packaging/nothing-os/install.sh. The bar knows the "triat" item natively
// and loads that file only when it is there, so:
//   - without Triat nothing breaks (no "TriatBarItem is not a type"),
//   - Triat's installer finds `triatPart` and `id: "triat"` already here
//     and patches no file of the rice, so updates no longer clash with it.
Singleton {
    id: root

    readonly property string module: Quickshell.shellPath("components/bar/TriatBarItem.qml")
    property bool installed: false

    NProcess {
        // Absent is the usual answer, not a fault.
        quiet: true
        running: true
        command: ["sh", "-c", '[ -f "$1" ] && echo yes', "triat-probe", root.module]
        stdout: StdioCollector {
            onStreamFinished: root.installed = text.trim() === "yes"
        }
    }
}
