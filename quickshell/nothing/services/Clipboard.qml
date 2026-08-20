pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist.
Singleton {
    id: root

    property var items: []          // { id, preview, isImage }
    property bool loading: false

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

    // cliphist list returns "<id>\t<preview>" per line.
    Process {
        id: lister
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
            }
        }
    }

    Process { id: runner }

    Component.onCompleted: refresh()
    onAvailableChanged: if (available) refresh()

    function refresh(): void {
        if (!root.available) {
            root.loading = false;
            return;
        }
        root.loading = true;
        lister.command = ["sh", "-c", "cliphist list"];
        lister.running = true;
    }

    // Copies the entry back into the current clipboard.
    function copy(id: string): void {
        runner.command = ["sh", "-c",
            `cliphist decode ${JSON.stringify(id)} | wl-copy`];
        runner.running = true;
    }

    function remove(id: string): void {
        runner.command = ["sh", "-c",
            `cliphist decode ${JSON.stringify(id)} | cliphist delete`];
        runner.running = true;
        removeTimer.restart();
    }

    function wipe(): void {
        runner.command = ["sh", "-c", "cliphist wipe"];
        runner.running = true;
        removeTimer.restart();
    }

    // cliphist writes asynchronously: re-read right after.
    Timer { id: removeTimer; interval: 180; onTriggered: root.refresh() }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "") return root.items;
        return root.items.filter(i => i.preview.toLowerCase().includes(q));
    }
}
