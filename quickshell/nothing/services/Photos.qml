pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Pictures for the photo widget.
//
// Nothing's own Photos widget picks from an album; here it is a folder,
// which is the desktop equivalent. The scan is one command rather than a
// directory watcher: the folder is read when the shell starts and when
// asked, and a photo frame is not something that needs to notice a new
// file within the second.
Singleton {
    id: root

    property var files: []
    readonly property bool ready: files.length > 0

    // Which one is showing. Advanced by the widget's own timer, so several
    // frames on the desktop stay in step rather than drifting apart.
    property int index: 0

    function next(): void {
        if (root.files.length > 0)
            root.index = (root.index + 1) % root.files.length;
    }

    readonly property string current:
        root.files.length > 0 ? root.files[root.index % root.files.length] : ""

    function refresh(): void {
        scan.running = false;
        scan.running = true;
    }

    onFilesChanged: root.index = 0

    Connections {
        target: Config
        function onPhotoDirChanged(): void { root.refresh(); }
    }

    NProcess {
        id: scan
        running: true
        // The folder is a setting, so it goes in as $1 and never into the
        // script text. Depth 2 keeps a nested album in reach without
        // walking someone's entire home directory.
        command: ["sh", "-c",
            'd="$1"; [ -d "$d" ] || exit 0; ' +
            'find "$d" -maxdepth 2 -type f ' +
            '\\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" ' +
            '-o -iname "*.webp" \\) 2>/dev/null | sort | head -60',
            "photos", Config.photoDir]

        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.trim().split("\n").filter(l => l.length > 0);
            }
        }
    }
}
