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
    property var values: root._zeros()

    // A second reason to run it besides the Glyph toy: a widget that
    // wants to move with the music sets this itself while it is on
    // screen, the same "nobody is looking, stop reading the mixer"
    // reasoning extended to a second listener rather than duplicated
    // for it.
    property bool widgetWantsIt: false

    readonly property bool listening:
        (Config.glyphEnabled && Config.glyphToy === "visualizer")
            || root.widgetWantsIt

    readonly property int bars: 25
    readonly property string confPath: `${Config.dir}/cava.conf`

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

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() === "yes"
        }
    }

    // The config never changes between one start and the next, so
    // pausing and resuming asks to write the same bytes twice. A
    // FileView has nothing to do on the second call and `onSaved`
    // stays quiet - which, if that were the only thing starting cava,
    // left it dead after a pause. This remembers what is already on
    // disk so a resume can start the process directly instead of
    // waiting on a write that is not going to happen.
    property string _written: ""

    FileView {
        id: confFile
        printErrors: false
        onSaved: {
            if (root.listening && root.available)
                cava.running = true;
        }
    }

    function _apply(): void {
        if (root.listening && root.available) {
            confFile.path = root.confPath;
            if (root._written === root.confText) {
                cava.running = true;
            } else {
                root._written = root.confText;
                confFile.setText(root.confText);
            }
        } else {
            cava.running = false;
            root.values = root._zeros();
        }
    }

    onListeningChanged: root._apply()
    onAvailableChanged: root._apply()
    // A binding's own first value is not a "change": without this, a
    // config that already starts with the visualiser toy chosen would
    // sit silent until something else happened to flip the property.
    Component.onCompleted: root._apply()

    NProcess {
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
