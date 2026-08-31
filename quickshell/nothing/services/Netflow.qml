pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What is going through the wire, in bytes per second.
//
// Nothing's equivalent counts mobile data against a monthly allowance,
// which no desktop has. What a desktop does have is throughput, and that
// is the reading worth a widget: not how much you have used this month
// but whether something is downloading right now.
//
// /proc/net/dev, differenced. It is counters, not rates, so the first tick
// after starting has nothing to compare against and reports zero rather
// than a spike of everything since boot.
Singleton {
    id: root

    property real rx: 0        // bytes per second, in
    property real tx: 0        // bytes per second, out
    property bool ready: false

    // Sixty samples, one per tick, for the sparkline.
    property var rxHistory: []
    property var txHistory: []
    readonly property int span: 60

    // Loopback would double every local transfer, and the virtual
    // interfaces a container runtime leaves behind would count it again.
    readonly property var skip: ["lo", "docker", "br-", "veth", "virbr", "tun", "tap"]

    property real lastRx: 0
    property real lastTx: 0
    property real lastAt: 0

    readonly property real peak: {
        const all = root.rxHistory.concat(root.txHistory);
        // A floor, so an idle link does not draw its own noise as a
        // mountain range.
        return Math.max(64 * 1024, ...all);
    }

    function human(bps: real): string {
        if (!isFinite(bps) || bps < 1)
            return "0 B/s";
        const units = ["B", "K", "M", "G"];
        let v = bps, i = 0;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1))
            + " " + units[i] + "/s";
    }

    FileView {
        id: dev
        path: "/proc/net/dev"

        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of dev.text().split("\n")) {
                const at = line.indexOf(":");
                if (at < 0)
                    continue;
                const name = line.slice(0, at).trim();
                if (root.skip.some(p => name === p || name.startsWith(p)))
                    continue;
                const f = line.slice(at + 1).trim().split(/\s+/);
                rx += parseInt(f[0]) || 0;
                tx += parseInt(f[8]) || 0;
            }

            const now = Date.now() / 1000;
            if (root.lastAt > 0) {
                const dt = now - root.lastAt;
                if (dt > 0) {
                    // Counters are 64-bit but they do reset when an
                    // interface goes away. A negative delta is that, not
                    // a negative rate.
                    root.rx = Math.max(0, (rx - root.lastRx) / dt);
                    root.tx = Math.max(0, (tx - root.lastTx) / dt);
                    root.ready = true;

                    root.rxHistory = root.rxHistory
                        .concat(root.rx).slice(-root.span);
                    root.txHistory = root.txHistory
                        .concat(root.tx).slice(-root.span);
                }
            }
            root.lastRx = rx;
            root.lastTx = tx;
            root.lastAt = now;
        }
    }

    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: dev.reload()
    }
}
