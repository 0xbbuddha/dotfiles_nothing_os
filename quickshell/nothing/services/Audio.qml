pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Pipewire sinks, microphone, per-application streams.
Singleton {
    id: root

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

    PwObjectTracker { objects: [root.sink, root.source] }
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
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
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
