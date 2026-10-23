pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The phone, through KDE Connect (kdeconnect-cli / its D-Bus service).
//
// Clipboard sync is KDE Connect's own: with its Clipboard plugin on (on
// both sides), what you copy on the phone lands in this clipboard, so
// cliphist keeps it in the history like anything else, and what you copy
// here goes to the phone. What the rice adds: starting the daemon at
// login (KDE Connect's autostart entry is an XDG one, which Hyprland does
// not run), the phone and its battery in the control centre, and a few
// actions: send the clipboard now, ring it, ping it.
//
// Optional throughout: without kdeconnect-cli nothing here runs and the
// settings page says what to install. Read when the control centre or the
// page asks, every minute while one of them is open, never otherwise.
Singleton {
    id: root

    property bool available: false
    property bool probed: false
    property var devices: []        // [{ id, name, charge, charging }]
    property string status: ""
    // Read while the control centre or the settings are open, and when
    // either opens; the phone is not polled otherwise.
    readonly property bool live: GlobalState.controlCenterOpen || GlobalState.settingsOpen
    onLiveChanged: if (root.live) root.refresh()

    readonly property var first: root.devices[0] ?? null

    NProcess {
        id: probe
        quiet: true
        running: true
        command: ["sh", "-c", "command -v kdeconnect-cli >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                root.probed = true;
                // --refresh also starts the daemon through D-Bus activation,
                // wherever the distribution put its binary.
                if (root.available && Config.phoneStart)
                    Quickshell.execDetached(["kdeconnect-cli", "--refresh"]);
                if (root.available)
                    root.refresh();
            }
        }
    }

    function refresh(): void {
        if (!root.available || lister.running)
            return;
        lister.running = true;
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.available && root.live
        onTriggered: root.refresh()
    }

    // Reachable, paired devices: "<id> <name>" per line.
    NProcess {
        id: lister
        quiet: true
        command: ["kdeconnect-cli", "--list-available", "--id-name-only"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^([A-Za-z0-9_]{8,})\s+(.+)$/);
                    if (m)
                        list.push({ id: m[1], name: m[2], charge: -1, charging: false });
                }
                root.devices = list;
                if (list.length > 0)
                    root.readBattery(list[0].id);
            }
        }
    }

    // busctl answers "i 85" and "b true". A phone without the battery
    // plugin simply shows no level.
    function readBattery(id: string): void {
        battery.target = id;
        battery.command = ["sh", "-c",
            'p="/modules/kdeconnect/devices/$1/battery"; i=org.kde.kdeconnect.device.battery; '
            + 'busctl --user get-property org.kde.kdeconnect "$p" "$i" charge; '
            + 'busctl --user get-property org.kde.kdeconnect "$p" "$i" isCharging', "phone-battery", id];
        battery.running = true;
    }

    NProcess {
        id: battery
        quiet: true
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.match(/^i\s+(-?\d+)/m);
                const ch = text.match(/^b\s+(true|false)/m);
                root.devices = root.devices.map(d => d.id !== battery.target ? d
                    : Object.assign({}, d, { charge: c ? parseInt(c[1], 10) : -1,
                                             charging: ch ? ch[1] === "true" : false }));
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────
    function act(id: string, args: var, done: string): void {
        if (!id)
            return;
        actor.done = done;
        actor.command = ["kdeconnect-cli", "-d", id].concat(args);
        actor.running = true;
    }

    function ring(id: string): void { root.act(id, ["--ring"], "Ringing"); }
    function ping(id: string): void { root.act(id, ["--ping"], "Pinged"); }

    // The clipboard as text, read by wl-paste and passed as an argument.
    function sendClipboard(id: string): void {
        if (!id)
            return;
        actor.done = "Clipboard sent";
        actor.command = ["sh", "-c",
            't="$(wl-paste -n -t text 2>/dev/null)"; [ -n "$t" ] || { echo "The clipboard has no text" >&2; exit 2; }; '
            + 'kdeconnect-cli -d "$1" --share-text "$t"', "phone-send", id];
        actor.running = true;
    }

    NProcess {
        id: actor
        quiet: true
        property string done: ""
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            root.status = code === 0 ? actor.done
                : (actErr.text.trim().split("\n")[0] || "The phone did not answer");
            statusClear.restart();
        }
    }

    Timer { id: statusClear; interval: 4000; onTriggered: root.status = "" }

    function openApp(): void {
        Quickshell.execDetached(["sh", "-c",
            "command -v kdeconnect-app >/dev/null && exec kdeconnect-app || exec kdeconnect-settings"]);
    }
}
