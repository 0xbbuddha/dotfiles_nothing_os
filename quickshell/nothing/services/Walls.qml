pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Images for the wallpaper picker and the slideshow.
//
//   folderFiles  the wallpaper folder (Config.wallpaperFolder), by name:
//                what "next" and the timer walk through
//   files        that folder first, then the rice's own pictures and the
//                usual Pictures folders, newest first, up to 300
//
// Folders travel as arguments, never inside the script. Re-read when the
// picker or the settings page opens, or after the folder changes; a
// folder with thousands of images is cut at depth 3 and 300 entries.
Singleton {
    id: root

    property var files: []
    property var folderFiles: []
    property bool scanning: false

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string folder: {
        const f = (Config.wallpaperFolder ?? "").trim();
        if (f === "")
            return root.home + "/Pictures/Wallpapers";
        return f.startsWith("~/") ? root.home + f.slice(1) : f;
    }

    onFolderChanged: root.refresh()

    function refresh(): void {
        probe.running = false;
        root.scanning = true;
        probe.command = ["sh", "-c",
            'f="$1"; shift; '
            // The folder alone, by name, for the slideshow.
            + 'if [ -d "$f" ]; then find "$f" -maxdepth 3 -type f \\( -iname "*.png" -o -iname "*.jpg" '
            + '-o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null | sort | head -300 | sed "s/^/F /"; fi; '
            // Everything, newest first, the folder first among equals.
            + 'for d in "$f" "$@"; do [ -d "$d" ] && find "$d" -maxdepth 3 -type f \\( -iname "*.png" '
            + '-o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -printf "%T@ %p\\n" 2>/dev/null; done '
            + '| sort -rn | cut -d" " -f2- | awk \'!seen[$0]++\' | head -300 | sed "s/^/A /"',
            "walls", root.folder,
            Quickshell.shellPath("../../hypr"), Quickshell.shellPath("assets"),
            root.home + "/Pictures", root.home + "/Images", root.home + "/Documents"];
        probe.running = true;
    }

    NProcess {
        id: probe
        label: "wallpapers"
        stdout: StdioCollector {
            onStreamFinished: {
                const all = [], mine = [];
                for (const line of text.split("\n")) {
                    if (line.startsWith("F "))
                        mine.push(line.slice(2));
                    else if (line.startsWith("A "))
                        all.push(line.slice(2));
                }
                root.folderFiles = mine;
                root.files = all;
                root.scanning = false;
            }
        }
    }

    Component.onCompleted: root.refresh()
}
