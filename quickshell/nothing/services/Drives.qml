pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// USB sticks, SD cards and external disks: mounted when plugged in, said
// so in a notification, listed in the control centre with Open and Eject.
//
// udisks does the work (udisksctl), as a file manager would: mounting a
// removable drive as the logged-in user is allowed by its own polkit rules,
// so there is no sudo and no fstab edit. The list is lsblk's, re-read when
// udev reports a block device appearing, changing or going away, never on a
// timer. Only drives plugged in while the shell runs are mounted on their
// own; one already there at login is listed and left alone, as is anything
// encrypted (the file manager asks for its passphrase).
Singleton {
    id: root

    property bool available: false     // udisksctl present
    // [{ path, disk, label, size, fstype, mount, encrypted }]
    property var list: []
    readonly property var mounted: root.list.filter(d => d.mount !== "")
    property var known: ({})           // path -> true, what has been seen
    property bool primed: false

    NProcess {
        id: probe
        quiet: true
        running: true
        command: ["sh", "-c", "command -v udisksctl >/dev/null && command -v lsblk >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                if (root.available) {
                    root.refresh();
                    watcher.running = true;
                }
            }
        }
    }

    // One long-lived process, events only.
    NProcess {
        id: watcher
        quiet: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: (line) => {
                if (/\s(add|remove|change)\s/.test(line))
                    settle.restart();
            }
        }
    }

    // A plug-in is a burst of events (disk, then each partition).
    Timer { id: settle; interval: 700; onTriggered: root.refresh() }

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    function human(bytes: real): string {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0, v = bytes;
        while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + u[i];
    }

    NProcess {
        id: lister
        label: "drives"
        command: ["lsblk", "-J", "-b", "-o",
                  "PATH,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TYPE,TRAN,PKNAME"]
        stdout: StdioCollector {
            onStreamFinished: {
                let tree;
                try { tree = JSON.parse(text); } catch (e) { return; }
                const out = [];
                const walk = (nodes, tran, removable) => {
                    for (const n of nodes ?? []) {
                        // The bus is on the disk, not on its partitions.
                        const t = n.tran ?? tran;
                        const r = removable || n.rm === true || n.rm === "1"
                                  || n.hotplug === true || n.hotplug === "1";
                        if (r && (t === "usb" || t === "mmc" || t === null || t === undefined)
                            && n.fstype && n.fstype !== "swap"
                            && (n.type === "part" || n.type === "disk")) {
                            out.push({
                                path: n.path,
                                disk: n.pkname ? "/dev/" + n.pkname : n.path,
                                label: n.label || n.path.split("/").pop(),
                                size: root.human(Number(n.size) || 0),
                                fstype: n.fstype,
                                mount: n.mountpoint ?? "",
                                encrypted: n.fstype === "crypto_LUKS"
                            });
                        }
                        walk(n.children, t, r);
                    }
                };
                walk(tree.blockdevices, null, false);
                root.arrived(out);
                root.list = out;
            }
        }
    }

    function arrived(now: var): void {
        const seen = Object.assign({}, root.known);
        for (const d of now) {
            if (seen[d.path])
                continue;
            seen[d.path] = true;
            // The first read is what was there at login: listed, not mounted.
            if (!root.primed)
                continue;
            if (d.encrypted)
                root.notify(d.label + " plugged in", "Encrypted: open it from the file manager to unlock it");
            else if (d.mount === "" && Config.drivesAutomount)
                root.mount(d.path);
            else
                root.notify(d.label + " plugged in", d.size + (d.mount !== "" ? " · " + d.mount : ""));
        }
        // Gone ones are forgotten, so plugging it back in counts as new.
        for (const p in seen)
            if (!now.some(d => d.path === p))
                delete seen[p];
        root.known = seen;
        root.primed = true;
    }

    function notify(title: string, body: string): void {
        if (!Config.drivesNotify)
            return;
        Quickshell.execDetached(["notify-send", "-a", "Nothing", "-i", "drive-removable-media",
                                 title, body]);
    }

    // ── Actions, one at a time ────────────────────────────────────────
    property string busyPath: ""

    function mount(path: string): void {
        root.run("mount", path, ["udisksctl", "mount", "-b", path, "--no-user-interaction"]);
    }

    function open(d: var): void {
        if (d.mount !== "")
            Quickshell.execDetached(["xdg-open", d.mount]);
        else
            root.mount(d.path);
    }

    // Unmount every mounted partition of the same disk, then power the
    // disk off: once that answers, pulling the cable is safe.
    function eject(d: var): void {
        const parts = root.list.filter(x => x.disk === d.disk && x.mount !== "").map(x => x.path);
        const script = 'for p in "$@"; do [ "$p" = -- ] && break; udisksctl unmount -b "$p" --no-user-interaction || exit 1; shift; done; shift; '
                     + 'udisksctl power-off -b "$1" --no-user-interaction';
        root.run("eject", d.disk, ["sh", "-c", script, "eject"].concat(parts, ["--", d.disk]));
    }

    // One udisksctl at a time; the rest wait their turn (a disk with two
    // partitions mounts both, not just the first).
    property var waiting: []

    function run(kind: string, path: string, cmd: var): void {
        if (actor.running || root.busyPath !== "") {
            root.waiting = root.waiting.concat([{ kind: kind, path: path, cmd: cmd }]);
            return;
        }
        root.busyPath = path;
        actor.kind = kind;
        actor.target = path;
        actor.command = cmd;
        actor.running = true;
    }

    NProcess {
        id: actor
        quiet: true
        property string kind: ""
        property string target: ""
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            const d = root.list.find(x => x.path === actor.target || x.disk === actor.target);
            const name = d?.label ?? actor.target;
            root.busyPath = "";
            if (code !== 0) {
                // "target is busy" is the usual one: a file still open.
                const why = (actErr.text.trim().split("\n").pop() || ("exit " + code))
                    .replace(/^Error [^:]*: ?/, "");
                console.warn("drives: " + actor.kind + " " + actor.target + ": " + why);
                Quickshell.execDetached(["notify-send", "-a", "Nothing", "-u", "critical",
                    (actor.kind === "eject" ? "Cannot eject " : "Cannot mount ") + name,
                    /busy/i.test(why) ? "Something still has a file open on it. Close it and try again." : why]);
            } else if (actor.kind === "eject") {
                root.notify(name + " can be removed", "Unmounted and powered off");
            } else {
                const at = (actOut.text.match(/ at (.+?)\.?\s*$/m) ?? [])[1] ?? "";
                root.notify(name + " mounted", (d?.size ?? "") + (at !== "" ? " · " + at : ""));
            }
            root.refresh();
            if (root.waiting.length > 0) {
                const n = root.waiting[0];
                root.waiting = root.waiting.slice(1);
                Qt.callLater(() => root.run(n.kind, n.path, n.cmd));
            }
        }
    }
}
