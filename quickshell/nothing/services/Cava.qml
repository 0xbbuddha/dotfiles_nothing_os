pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Audio visualiser for the Glyph Matrix.
//
// cava is only started when `listening` is true: a permanent Pulse/PipeWire
// daemon for a toy nobody is looking at would be waste.
// The config is rewritten on every start, to stay aligned with the
// matrix's 25 bars.
Singleton {
    id: root

    property bool available: false
    property bool listening: false
    property bool osdHold: false
    property var values: root._zeros()

    readonly property int bars: 25
    readonly property string confPath: `${Config.dir}/cava.conf`

    function sync(): void {
        root.listening = Config.glyphEnabled
            && (Config.glyphToy === "visualizer" || root.osdHold);
    }

    Component.onCompleted: root.sync()

    Connections {
        target: Config
        function onGlyphToyChanged(): void { root.sync(); }
        function onGlyphEnabledChanged(): void { root.sync(); }
    }

    onOsdHoldChanged: root.sync()

    function _zeros(): var {
        const a = [];
        for (let i = 0; i < root.bars; i++)
            a.push(0);
        return a;
    }

    readonly property string confText:
        "[general]\n"
        + "bars = " + root.bars + "\n"
        + "framerate = 30\n"
        + "autosens = 1\n"
        + "\n"
        + "[output]\n"
        + "method = raw\n"
        + "raw_target = /dev/stdout\n"
        + "data_format = ascii\n"
        + "ascii_max_range = 100\n"
        + "channels = mono\n"
        + "\n"
        + "[smoothing]\n"
        + "monstercat = 0\n"
        + "noise_reduction = 77\n"

    Process {
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() === "yes"
        }
    }

    FileView {
        id: confFile
        printErrors: false
        onSaved: {
            if (root.listening && root.available)
                cava.running = true;
        }
    }

    onListeningChanged: {
        if (root.listening && root.available) {
            confFile.path = root.confPath;
            confFile.setText(root.confText);
        } else {
            cava.running = false;
            root.values = root._zeros();
        }
    }

    Process {
        id: cava
        running: false
        command: ["cava", "-p", root.confPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const parts = data.trim().split(";");
                const next = root._zeros();
                let n = 0;
                for (let i = 0; i < parts.length && n < root.bars; i++) {
                    if (parts[i] === "")
                        continue;
                    next[n] = Math.max(0, Math.min(1, (parseInt(parts[i], 10) || 0) / 100));
                    n++;
                }
                root.values = next;
            }
        }
    }
}
