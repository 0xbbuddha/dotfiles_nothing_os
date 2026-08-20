pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist.
Singleton {
    id: root

    property var items: []          // { id, preview, isImage }
    property bool loading: false
    // Search.results is a binding: it only re-runs if it reads a
    // property that changed. stamp is that property.
    property int stamp: 0

    readonly property bool available: probe.found

    Process {
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: probe.found = text.trim() === "yes"
        }
    }

    // cliphist list returns "<id>\t<preview>" per line, newest first.
    Process {
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

    Process { id: runner }

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

    // Copies the entry back into the current clipboard.
    function copy(id: string): void {
        runner.command = ["sh", "-c",
            `cliphist decode ${JSON.stringify(id)} | wl-copy`];
        runner.running = false;
        runner.running = true;
    }

    function remove(id: string): void {
        runner.command = ["sh", "-c",
            `printf '%s\\t' ${JSON.stringify(id)} | cliphist delete`];
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
