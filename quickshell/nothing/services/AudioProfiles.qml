pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Which physical output a sound card is using right now - the analogue
// jack or HDMI, never both. Pipewire's own QML binding only sees sinks,
// never the ALSA card profile that decides which sinks can even exist,
// so plugging a TV into HDMI does not make a sink appear on its own: the
// card is still set to "analogue", the same way it was before the cable
// went in. Swapping that needs pactl; nothing in Quickshell.Services.
// Pipewire reaches it.
Singleton {
    id: root

    // [{ card, id, label, active }], output profiles only - "off",
    // "pro-audio" and input-only profiles are not something to switch to
    // from a sound flyout.
    property var profiles: []
    property bool busy: false

    readonly property var labels: ({
        "analog-stereo": "Speakers",
        "hdmi-stereo": "HDMI",
        "hdmi-stereo-extra1": "HDMI 2",
        "hdmi-stereo-extra2": "HDMI 3",
        "hdmi-stereo-extra3": "HDMI 4",
        "hdmi-surround": "HDMI (5.1)",
        "hdmi-surround71": "HDMI (7.1)"
    })

    function labelFor(id: string): string {
        // "output:hdmi-stereo+input:analog-stereo" -> "hdmi-stereo"
        const out = id.split("+")[0];
        const key = out.startsWith("output:") ? out.slice(7) : out;
        return root.labels[key] ?? key.replace(/-/g, " ");
    }

    function refresh(): void { lister.running = true; }

    function setProfile(card: string, id: string): void {
        if (root.busy || card === "" || id === "") return;
        root.busy = true;
        switcher.command = ["pactl", "set-card-profile", card, id];
        switcher.running = true;
    }

    Component.onCompleted: root.refresh()

    // A profile switch changes which sinks exist, and a hotplug (TV
    // turned off, headphones out of the jack) can too: either is reason
    // enough to re-read what is actually available now.
    Connections {
        target: Audio
        function onSinksChanged(): void { root.refresh(); }
    }

    NProcess {
        id: lister
        quiet: true
        command: ["pactl", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                // One card at a time: each block carries its own name,
                // profile list and active profile, and nothing here
                // needs to read across the boundary.
                const blocks = text.split(/\nCard #/)
                    .map((b, i) => i === 0 ? b : "Card #" + b);
                for (const block of blocks) {
                    const nameM = block.match(/\n\tName:\s*(.+)/);
                    if (!nameM) continue;
                    const card = nameM[1].trim();
                    const activeM = block.match(/\n\tActive Profile:\s*(.+)/);
                    const active = activeM ? activeM[1].trim() : "";
                    const profSection =
                        block.match(/\n\tProfiles:\n([\s\S]*?)\n\t[A-Z]/);
                    if (!profSection) continue;
                    for (const line of profSection[1].split("\n")) {
                        // \S+ rather than [^:]+: the id itself has a
                        // colon in it ("output:analog-stereo"), so the
                        // first colon is not the one that ends it.
                        const m = line.match(
                            /^\t\t(\S+):\s.*\(sinks:\s*(\d+),\s*sources:\s*\d+,\s*priority:\s*-?\d+,\s*available:\s*(yes|no)\)/);
                        if (!m) continue;
                        const id = m[1];
                        const sinks = parseInt(m[2], 10);
                        const avail = m[3] === "yes";
                        // "+input:..." duplex variants exist so a mic can
                        // ride along; the flyout offers the plain output,
                        // never a second identical row for the same jack.
                        if (id.startsWith("output:") && !id.includes("+input")
                            && sinks > 0 && avail) {
                            found.push({
                                card, id, label: root.labelFor(id),
                                active: id === active
                            });
                        }
                    }
                }
                root.profiles = found;
            }
        }
    }

    NProcess {
        id: switcher
        quiet: true
        onExited: { root.busy = false; root.refresh(); }
    }
}
