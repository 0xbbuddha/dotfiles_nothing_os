pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Times in other zones, for the world clock widget.
//
// QML's engine has no Intl, so a zone name cannot be turned into a time in
// process. One batched shell call handles every zone at once, once a
// minute: a process per city per tick would be absurd, and a stored UTC
// offset would be wrong twice a year.
Singleton {
    id: root

    // { zone, label, time } per configured city.
    property var clocks: []

    readonly property var zones: Config.worldClocks ?? []

    // "Europe/Paris" reads as "Paris" on a widget; the region is noise
    // once you have chosen the city yourself.
    function shortName(zone: string): string {
        const parts = String(zone).split("/");
        return (parts[parts.length - 1] ?? zone).replace(/_/g, " ");
    }

    function refresh(): void {
        poll.running = false;
        poll.running = true;
    }

    onZonesChanged: root.refresh()

    NProcess {
        id: poll
        running: true
        // Zones come from the config, so they are positional arguments and
        // never part of the script. A zone that does not exist prints
        // nothing rather than failing the whole batch.
        command: ["sh", "-c",
            'for z in "$@"; do ' +
            'if [ -e "/usr/share/zoneinfo/$z" ]; then ' +
            'printf "%s\\t%s\\n" "$z" "$(TZ="$z" date +%H:%M)"; fi; done',
            "worldtime"].concat(root.zones)

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    const z = line.slice(0, tab);
                    out.push({
                        zone: z,
                        label: root.shortName(z),
                        time: line.slice(tab + 1).trim()
                    });
                }
                root.clocks = out;
            }
        }
    }

    // Aligned to the minute rather than every sixty seconds from startup,
    // so the displayed time flips when the minute does.
    Timer {
        running: true
        repeat: true
        interval: 1000 * (61 - new Date().getSeconds())
        onTriggered: {
            root.refresh();
            interval = 1000 * (61 - new Date().getSeconds());
        }
    }
}
