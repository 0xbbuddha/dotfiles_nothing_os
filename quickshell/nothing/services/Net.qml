pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Io

// Network and Bluetooth via Quickshell's native modules.
Singleton {
    id: root

    // ── Network ───────────────────────────────────────────────────────
    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var ethernet: devices.find(d =>
        d.type !== DeviceType.Wifi && d.connected && d.name !== "lo") ?? null

    readonly property var networks: wifiDevice?.networks?.values ?? []
    readonly property var activeWifi: networks.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiAvailable: wifiDevice !== null

    readonly property string kind: ethernet ? "ethernet" : (activeWifi ? "wifi" : "none")
    readonly property string name: {
        if (ethernet) return ethernet.name;
        if (activeWifi) return activeWifi.name;
        return wifiEnabled ? "Not connected" : "Wi-Fi off";
    }
    readonly property real strength: activeWifi?.signalStrength ?? 0

    readonly property string glyph: {
        // 󰖩 / 󰖪 (wifi / wifi-off) are symmetrical, unlike the
        // "strength" 󰤨 glyphs which sit top-left in a circle.
        if (kind === "ethernet") return "󰈀";
        if (kind !== "wifi") return "󰖪";
        return "󰖩";
    }

    // ── Bluetooth ─────────────────────────────────────────────────────
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btPowered: adapter?.enabled ?? false
    readonly property bool btScanning: adapter?.discovering ?? false
    readonly property var btDevices: adapter?.devices?.values ?? []

    // Connected first, then what is already paired, then whatever the
    // scan turned up. Unsorted, a passing phone could sit above your
    // headphones.
    function sortedBt(): var {
        const mac = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/;
        return root.btDevices.slice().sort((a, b) => {
            const rank = d => d.connected ? 0 : (d.paired ? 1 : 2);
            const ra = rank(a);
            const rb = rank(b);
            if (ra !== rb)
                return ra - rb;
            // Anything still showing a bare MAC has not announced itself
            // yet; it belongs under the devices that have a real name.
            const an = String(a.name || a.address);
            const bn = String(b.name || b.address);
            const am = mac.test(an);
            const bm = mac.test(bn);
            if (am !== bm)
                return am ? 1 : -1;
            return an.localeCompare(bn);
        });
    }

    // Connecting without trusting means BlueZ will not bring the device
    // back on its own next time, which is most of what you want from a
    // speaker.
    function btConnect(device: var): void {
        if (!device)
            return;
        root.btMessage = "";
        btClear.stop();
        root.btPending = device.address;
        btWatch.restart();

        if (device.connected) {
            root.btPending = "";
            btWatch.stop();
            root.scanBt(false);
            device.disconnect();
            return;
        }

        if (device.paired) {
            // A known device is reached from BlueZ's own records, and an
            // active scan only steals the radio from the handshake.
            root.scanBt(false);
            if (!device.trusted)
                device.trusted = true;
            device.connect();
            return;
        }

        // A device that has never been paired only exists in BlueZ for as
        // long as discovery holds it: stop scanning first and pairing
        // fails outright with "not available". So the scan stays up, and
        // `pairWatch` takes it down the moment the pairing lands.
        root.scanBt(true);
        device.pair();
    }

    // NoInputNoOutput pairing, which scripts/bt-agent.sh registers, covers
    // speakers and headphones but cannot answer a device that wants a
    // passkey typed. KDE's wizard brings a full agent for those, which is
    // also how the illogical-impulse config handles pairing throughout.
    property bool btWizard: false

    Process {
        running: true
        command: ["sh", "-c",
            "command -v bluedevil-wizard >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.btWizard = text.trim() === "yes"
        }
    }

    function openBtWizard(): void {
        if (!root.btWizard)
            return;
        root.scanBt(false);
        Quickshell.execDetached(["bluedevil-wizard"]);
    }

    // Bluetooth says nothing when a handshake fails: the row simply goes
    // back to how it was. Watching the attempt is the only way to tell
    // the difference between "still trying" and "gave up".
    property string btMessage: ""
    property string btPending: ""

    Timer {
        id: btWatch
        interval: 20000
        onTriggered: {
            const target = root.btDevices.find(d => d.address === root.btPending);
            root.btPending = "";
            if (!target || target.connected)
                return;
            root.btMessage = target.paired
                ? "Could not connect. Is it on and in range?"
                : "Could not pair. Put it in pairing mode and try again.";
            btClear.restart();
        }
    }

    Timer {
        id: btClear
        interval: 9000
        onTriggered: root.btMessage = ""
    }

    // Pairing done: hand the radio back and make the device stick, so
    // BlueZ brings it in by itself next time.
    Connections {
        target: root.adapter?.devices ?? null
        ignoreUnknownSignals: true
        function onValuesChanged(): void { root.settleBt(); }
    }

    function settleBt(): void {
        for (const d of root.btDevices) {
            if (d.paired && !d.trusted)
                d.trusted = true;
        }
        if (root.btConnected.length > 0 && root.btScanning)
            root.scanBt(false);
        // The attempt landed: stop expecting a failure.
        if (root.btPending !== "") {
            const target = root.btDevices.find(d => d.address === root.btPending);
            if (target && target.connected) {
                root.btPending = "";
                btWatch.stop();
            }
        }
    }

    // BlueZ hands us an icon name; a speaker should not look like a phone.
    function btGlyph(device: var): string {
        if (!device)
            return "󰂯";
        switch (device.icon ?? "") {
        case "audio-headset":
        case "audio-headphones":  return "󰋋";
        case "audio-card":
        case "audio-speakers":    return "󰓃";
        case "input-keyboard":    return "󰌌";
        case "input-mouse":       return "󰍽";
        case "input-gaming":      return "󰊴";
        case "phone":             return "󰄜";
        case "computer":          return "󰟀";
        case "camera-photo":
        case "camera-video":      return "󰄀";
        case "printer":           return "󰐪";
        case "video-display":     return "󰍹";
        default:                  return device.connected ? "󰂱" : "󰂯";
        }
    }

    // What the row should say on its right-hand side.
    function btStatus(device: var): string {
        if (!device)
            return "";
        if (device.pairing)
            return "pairing";
        if (device.state === BluetoothDeviceState.Connecting)
            return "connecting";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "disconnecting";
        if (device.connected)
            return "connected";
        if (device.paired)
            return "paired";
        return "";
    }

    readonly property bool btWorking: root.btDevices.some(d =>
        d.pairing || d.state === BluetoothDeviceState.Connecting
        || d.state === BluetoothDeviceState.Disconnecting)
    readonly property var btConnected: btDevices.filter(d => d.connected)
    readonly property string btLabel: btConnected.length > 0
        ? btConnected[0].name
        : (btPowered ? "On" : "Off")

    // ── Actions ───────────────────────────────────────────────────────
    function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }
    function toggleBt(): void { if (adapter) adapter.enabled = !adapter.enabled; }
    function scanWifi(on: bool): void { if (wifiDevice) wifiDevice.scannerEnabled = on; }
    function scanBt(on: bool): void { if (adapter) adapter.discovering = on; }

    function sortedNetworks(): var {
        return networks.slice().sort((x, y) => {
            if (x.connected !== y.connected) return x.connected ? -1 : 1;
            if (x.known !== y.known) return x.known ? -1 : 1;
            return (y.signalStrength ?? 0) - (x.signalStrength ?? 0);
        });
    }
}
