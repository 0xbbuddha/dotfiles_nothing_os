pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."

// Pipewire sinks, microphone, per-application streams.
Singleton {
    id: root

    // Shared with bt-a2dp-fix.sh's route_audio(): the same "move every
    // playing stream onto the new sink" loop used to live independently
    // in both and had already drifted into two slightly different ones.
    readonly property string moveScript:
        Quickshell.shellPath("../../scripts/move-sink-inputs.sh")

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var mic: source?.audio ?? null
    readonly property bool micMuted: mic?.muted ?? true
    readonly property bool hasMic: source !== null && mic !== null

    readonly property int nodeCount: Pipewire.nodes?.values?.length ?? 0
    readonly property var sinks: {
        const _ = root.nodeCount;
        return (Pipewire.nodes?.values ?? []).filter(n =>
            n.isSink && !n.isStream && n.audio);
    }
    readonly property var streams: {
        const _ = root.nodeCount;
        // Playback: an app stream into a sink. `!isSink` would be the mic.
        return (Pipewire.nodes?.values ?? []).filter(n =>
            n.isStream && n.isSink && n.audio);
    }

    // Capture devices. Streams are apps recording, not devices.
    readonly property var sources: {
        const _ = root.nodeCount;
        return (Pipewire.nodes?.values ?? []).filter(n =>
            !n.isSink && !n.isStream && n.audio);
    }

    PwObjectTracker { objects: [root.sink, root.source] }
    PwObjectTracker { objects: root.sources }
    PwObjectTracker { objects: root.sinks }
    PwObjectTracker { objects: root.streams }

    function nameOf(node): string {
        const n = node?.nickname || node?.description || node?.name || "";
        return n.length > 0 ? n : "Output";
    }

    function glyphFor(node): string {
        const n = [
            node?.nickname ?? "",
            node?.description ?? "",
            node?.name ?? ""
        ].join(" ").toLowerCase();
        if (n.includes("hdmi") || n.includes("displayport") || n.includes("dp "))
            return "󰡁";
        if (n.includes("headphone") || n.includes("headset") || n.includes("jack"))
            return "󰋋";
        if (n.includes("bluez") || n.includes("bluetooth"))
            return "󰂯";
        return "󰓃";
    }

    function isDefault(node): bool {
        return (root.sink?.id ?? -1) === (node?.id ?? -2);
    }

    function setSink(node): void {
        if (!node)
            return;
        // set the default and drag playing streams over, else a pinned one
        // stays put. runs first so a Pipewire binding hiccup can't skip it.
        sinkMover.running = false;
        sinkMover.command = ["sh", "-c",
            "wpctl set-default \"$1\" 2>/dev/null; \"$2\" \"$3\"",
            "set-sink", String(node.id), root.moveScript, String(node.name)];
        sinkMover.running = true;
        Pipewire.preferredDefaultAudioSink = node;
    }

    NProcess { id: sinkMover; label: "set sink" }

    function isDefaultSource(node): bool {
        return (root.source?.id ?? -1) === (node?.id ?? -2);
    }

    function setSource(node): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function toggleMic(): void {
        if (root.mic)
            root.mic.muted = !root.mic.muted;
    }

    function appName(node): string {
        return node?.properties["application.name"]
            || node?.nickname || node?.description || "App";
    }
}
