pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// CPU / RAM / GPU / temperatures, read directly from /proc and /sys.
Singleton {
    id: root

    property real cpu: 0        // 0..1
    property real ram: 0        // 0..1
    property real gpu: 0        // 0..1
    property int  cpuTemp: 0    // °C
    property int  gpuTemp: 0    // °C
    property bool gpuSeen: false
    property string kernel: ""

    // Which distribution this is, from os-release. Its ID_LIKE matters as
    // much as its name: EndeavourOS is Arch underneath, and the mark worth
    // showing is the one the system actually descends from.
    property string distro: ""
    property string distroId: ""
    property string distroLike: ""
    property string host: ""

    // Seconds since boot at the moment it was read, plus when that was, so
    // the figure stays live without a process polling for it.
    property real bootUptime: 0
    property real bootReadAt: 0

    readonly property real uptime: {
        void Time.now;
        return root.bootUptime > 0
            ? root.bootUptime + (Date.now() / 1000 - root.bootReadAt) : 0;
    }

    function prettyUptime(): string {
        const s = Math.max(0, Math.floor(root.uptime));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    readonly property string distroMark: {
        const all = (root.distroId + " " + root.distroLike).toLowerCase();
        return all.indexOf("arch") >= 0 ? "archLinux" : "";
    }

    // Memory in KiB, like /proc/meminfo. The recap shows used/free/total.
    property real ramTotalKb: 1
    property real ramFreeKb: 0
    readonly property real ramUsedKb: Math.max(0, ramTotalKb - ramFreeKb)

    property real zramTotalKb: 0
    property real zramUsedKb: 0
    property real diskSwapTotalKb: 0
    property real diskSwapUsedKb: 0

    readonly property bool hasZram: zramTotalKb > 0
    readonly property bool hasDiskSwap: diskSwapTotalKb > 0
    readonly property real zram: zramTotalKb > 0 ? zramUsedKb / zramTotalKb : 0
    readonly property real diskSwap: diskSwapTotalKb > 0 ? diskSwapUsedKb / diskSwapTotalKb : 0
    readonly property real zramFreeKb: Math.max(0, zramTotalKb - zramUsedKb)
    readonly property real diskSwapFreeKb: Math.max(0, diskSwapTotalKb - diskSwapUsedKb)

    readonly property string ramDetail: root.detailLine(ramUsedKb, ramFreeKb, ramTotalKb)
    readonly property string zramDetail: root.detailLine(zramUsedKb, zramFreeKb, zramTotalKb)
    readonly property string swapDetail: root.detailLine(diskSwapUsedKb, diskSwapFreeKb, diskSwapTotalKb)

    // Alert thresholds: beyond these, the UI turns red.
    // Recent history, so the gauges can show a trend and not just an
    // instant. Sampled with the poll below, so 40 slots is a little over
    // a minute: long enough to see a build spike come and go, short
    // enough that the row stays narrow.
    readonly property int historyLength: 40
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var zramHistory: []
    property var swapHistory: []

    function pushed(list: var, v: real): var {
        const a = (list ?? []).slice();
        a.push(Math.max(0, Math.min(1, v)));
        while (a.length > root.historyLength)
            a.shift();
        return a;
    }

    readonly property bool hot: cpuTemp >= 80 || gpuTemp >= 85
    readonly property bool busy: cpu > 0.85 || ram > 0.9

    function fmtGb(kb: real): string {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function detailLine(usedKb: real, freeKb: real, totalKb: real): string {
        return root.fmtGb(usedKb) + " used  ·  " + root.fmtGb(freeKb)
            + " free  ·  " + root.fmtGb(totalKb);
    }

    property int _prevTotal: 0
    property int _prevIdle: 0

    // Read once. None of it changes while the session runs, so polling it
    // beside the CPU would be four processes an hour for nothing.
    NProcess {
        running: true
        command: ["sh", "-c",
            ". /etc/os-release 2>/dev/null;"
            + " printf '%s\\n%s\\n%s\\n%s\\n'"
            + " \"${PRETTY_NAME:-$NAME}\" \"$ID\" \"$ID_LIKE\" \"$(uname -r)\";"
            + " uname -n; cut -d. -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.distro = (l[0] ?? "").trim();
                root.distroId = (l[1] ?? "").trim();
                root.distroLike = (l[2] ?? "").trim();
                root.kernel = (l[3] ?? "").trim();
                root.host = (l[4] ?? "").trim();
                root.bootUptime = parseFloat(l[5] ?? "0") || 0;
                root.bootReadAt = Date.now() / 1000;
            }
        }
    }

    NProcess {
        id: probe
        running: true
        command: ["sh", "-c", `
            awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print "CPU", t, $5+$6}' /proc/stat
            awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print "MEM", t+0, a+0}' /proc/meminfo
            awk 'NR>1 {
                if ($1 ~ /zram/) { zt+=$3; zu+=$4 }
                else { dt+=$3; du+=$4 }
            } END { print "SWAPDEV", zt+0, zu+0, dt+0, du+0 }' /proc/swaps
            for f in /sys/class/thermal/thermal_zone*/temp; do [ -r "$f" ] && cat "$f"; done \
                | sort -rn | head -1 | awk '{printf "CTEMP %d\\n", $1/1000}'
            if command -v nvidia-smi >/dev/null 2>&1; then
                nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
                    | head -1 | awk -F'[, ]+' '{print "GPU", $1, $2}'
            else
                for d in /sys/class/drm/card*/device; do
                    if [ -r "$d/gpu_busy_percent" ]; then
                        b=$(cat "$d/gpu_busy_percent")
                        t=$(cat "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
                        echo "GPU $b $((\${t:-0} / 1000))"
                        break
                    fi
                done
            fi
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                // Sampled once per poll, after every line of this batch has
                // been read: doing it per line would record the same tick
                // several times and squash the history.
                const sample = () => {
                    root.cpuHistory  = root.pushed(root.cpuHistory,  root.cpu);
                    root.ramHistory  = root.pushed(root.ramHistory,  root.ram);
                    root.gpuHistory  = root.pushed(root.gpuHistory,  root.gpu);
                    root.zramHistory = root.pushed(root.zramHistory, root.zram);
                    root.swapHistory = root.pushed(root.swapHistory, root.diskSwap);
                };
                for (const line of text.trim().split("\n")) {
                    const p = line.trim().split(/\s+/);
                    switch (p[0]) {
                    case "CPU": {
                        const total = parseInt(p[1]), idle = parseInt(p[2]);
                        const dt = total - root._prevTotal, di = idle - root._prevIdle;
                        if (root._prevTotal > 0 && dt > 0)
                            root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
                        root._prevTotal = total; root._prevIdle = idle;
                        break;
                    }
                    case "MEM": {
                        const t = Number(p[1]), a = Number(p[2]);
                        if (t > 0) {
                            root.ramTotalKb = t;
                            root.ramFreeKb = a;
                            root.ram = 1 - a / t;
                        }
                        break;
                    }
                    case "SWAPDEV":
                        root.zramTotalKb = Number(p[1]) || 0;
                        root.zramUsedKb = Number(p[2]) || 0;
                        root.diskSwapTotalKb = Number(p[3]) || 0;
                        root.diskSwapUsedKb = Number(p[4]) || 0;
                        break;
                    case "CTEMP": root.cpuTemp = parseInt(p[1]) || 0; break;
                    case "GPU":
                        root.gpuSeen = true;
                        root.gpu = (parseInt(p[1]) || 0) / 100;
                        root.gpuTemp = parseInt(p[2]) || 0;
                        break;
                    }
                }
                sample();
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: probe.running = true
    }
}
