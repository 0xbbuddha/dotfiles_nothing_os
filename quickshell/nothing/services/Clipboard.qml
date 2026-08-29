pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Clipboard history via cliphist.
Singleton {
    id: root

    property var items: []          // { id, preview, isImage }
    property bool loading: false
    // Search.results is a binding: it only re-runs if it reads a
    // property that changed. stamp is that property.
    property int stamp: 0

    readonly property bool available: probe.found

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: probe.found = text.trim() === "yes"
        }
    }

    // cliphist list returns "<id>\t<preview>" per line, newest first.
    NProcess {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: /^\[\[\s*binary.*(png|jpg|jpeg|bmp|webp|gif)/i.test(preview)
                    });
                }
                root.items = out;
                root.loading = false;
                root.stamp++;
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.loading = false;
                root.stamp++;
            }
        }
    }

    // NProcess reports stderr and a non-zero exit on its own, and the
    // script name passed as argv[0] is what it labels them with, so a
    // failure shows up as "clip-copy: id 370 not found" instead of nothing.
    NProcess { id: runner }

    Component.onCompleted: {
        root.refresh();
        Quickshell.execDetached([Quickshell.shellPath("../../scripts/ensure-cliphist.sh")]);
    }
    onAvailableChanged: if (available) refresh()

    // Text copies (images do not change clipboardText: the wl-paste
    // watcher notifies via ipc call clipboard update).
    Connections {
        target: Quickshell
        function onClipboardTextChanged(): void { debounce.restart(); }
    }

    Timer {
        id: debounce
        interval: 80
        onTriggered: root.refresh()
    }

    function refresh(): void {
        if (!root.available) {
            root.loading = false;
            return;
        }
        root.loading = true;
        // Reusing a finished Process requires a false→true edge.
        lister.running = false;
        lister.running = true;
    }

    // `cliphist decode ID | wl-copy` looks obvious and is wrong: a decode
    // that fails prints nothing, and wl-copy given nothing still takes the
    // selection, so a failed copy does not merely fail, it empties the
    // clipboard. Decode into a buffer, then only touch the selection if
    // something came out.
    //
    // The second half is the id going stale. cliphist renumbers an entry
    // whenever its content is stored again, so the preview is passed as a
    // second chance: it is the exact string cliphist itself printed, which
    // makes it safe to compare against a fresh listing.
    //
    // Both arguments are positional ($1, $2), never interpolated into the
    // script text, so a preview full of quotes or newlines cannot escape.
    readonly property string copyScript: `
        t=$(mktemp) || exit 1
        trap 'rm -f "$t"' EXIT
        cliphist decode "$1" >"$t" 2>/dev/null
        if [ ! -s "$t" ] && [ -n "$2" ]; then
            id=$(cliphist list | awk -v p="$2" '{ i = index($0, "\t")
                if (i && substr($0, i + 1) == p) { print substr($0, 1, i - 1); exit } }')
            [ -n "$id" ] && cliphist decode "$id" >"$t" 2>/dev/null
        fi
        [ -s "$t" ] && wl-copy <"$t"
    `

    function copy(id: string, preview: string): void {
        runner.command = ["sh", "-c", root.copyScript, "clip-copy",
                          id, preview ?? ""];
        runner.running = false;
        runner.running = true;
    }

    function remove(id: string): void {
        runner.command = ["sh", "-c", `printf '%s\\t' "$1" | cliphist delete`,
                          "clip-remove", id];
        runner.running = false;
        runner.running = true;
        removeTimer.restart();
    }

    function wipe(): void {
        runner.command = ["cliphist", "wipe"];
        runner.running = false;
        runner.running = true;
        removeTimer.restart();
    }

    Timer { id: removeTimer; interval: 180; onTriggered: root.refresh() }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "") return root.items;
        return root.items.filter(i => i.preview.toLowerCase().includes(q));
    }
}
