pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Which output each app plays to: Discord in the headset, the game on the
// speakers. Quickshell's Pipewire nodes say what an app is, not where it
// goes, so this asks pipewire-pulse (pactl, as AudioProfiles already does)
// and moves a stream with `pactl move-sink-input`. WirePlumber's
// restore-stream remembers the move per app (on by default), so the app
// goes back there next time it plays.
//
// Streams are matched by their PipeWire object.id, never by the pulse
// index: recent pipewire-pulse numbers those by serial, not by id.
Singleton {
    id: root

    property var routes: ({})      // stream node id -> { index, sink: sink node name }
    property bool busy: false

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    NProcess {
        id: lister
        label: "audio routes"
        // A constant script: two JSON documents, one per line.
        command: ["sh", "-c", "pactl -f json list sink-inputs; echo; pactl -f json list sinks", "audio-routes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const docs = text.split("\n").map(l => l.trim()).filter(l => l.startsWith("["));
                if (docs.length < 2)
                    return;
                let inputs, sinks;
                try { inputs = JSON.parse(docs[0]); sinks = JSON.parse(docs[1]); } catch (e) { return; }
                const sinkName = {};
                for (const s of sinks)
                    sinkName[s.index] = s.name;
                const out = {};
                for (const i of inputs) {
                    const id = parseInt(i.properties?.["object.id"] ?? "", 10);
                    if (!isNaN(id))
                        out[id] = { index: i.index, sink: sinkName[i.sink] ?? "" };
                }
                root.routes = out;
            }
        }
    }

    // The sink node a stream plays to now, or null if unknown.
    function sinkOf(stream: var): var {
        const r = root.routes[stream?.id ?? -1];
        if (!r)
            return null;
        return Audio.sinks.find(s => s.name === r.sink) ?? null;
    }

    function moveTo(stream: var, sink: var): void {
        const r = root.routes[stream?.id ?? -1];
        if (!r || !sink || root.busy)
            return;
        root.busy = true;
        mover.command = ["pactl", "move-sink-input", String(r.index), String(sink.name)];
        mover.running = true;
    }

    // The next output in the list: a click steps through them.
    function cycle(stream: var): void {
        const list = Audio.sinks;
        if (list.length < 2)
            return;
        const cur = root.sinkOf(stream);
        const i = cur ? list.findIndex(s => s.id === cur.id) : -1;
        root.moveTo(stream, list[(i + 1) % list.length]);
    }

    NProcess {
        id: mover
        label: "audio route"
        onExited: { root.busy = false; root.refresh(); }
    }

    // A new app starting to play, or an output appearing, changes the map.
    Connections {
        target: Audio
        function onStreamsChanged(): void { refreshLater.restart(); }
        function onSinksChanged(): void { refreshLater.restart(); }
    }

    Timer { id: refreshLater; interval: 300; onTriggered: root.refresh() }

    Component.onCompleted: root.refresh()
}
