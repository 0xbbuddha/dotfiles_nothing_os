pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Io
import ".."

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

    // ── Joining a network ─────────────────────────────────────────────
    //
    // The order is the one the backend documents: call connect() first,
    // because NetworkManager may already hold the secret, and only ask
    // for a password when it answers connectionFailed(NoSecrets). The
    // panel used to call connect() and listen to nothing, so a network
    // that wanted a password simply did nothing at all.
    property var pendingNet: null      // the attempt in flight
    property string wifiAsk: ""        // ssid waiting for a password
    property string wifiMessage: ""

    // A PSK is only meaningful for these. Anything else either needs no
    // secret or needs a certificate, which is not something a text field
    // can supply.
    function takesPsk(net: var): bool {
        if (!net)
            return false;
        switch (net.security) {
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Sae:
            return true;
        default:
            return false;
        }
    }

    function connectWifi(net: var): void {
        if (!net)
            return;
        root.wifiMessage = "";
        root.wifiAsk = "";
        if (net.connected) {
            root.pendingNet = null;
            net.disconnect();
            return;
        }
        root.pendingNet = net;
        net.connect();
    }

    function connectWifiPsk(net: var, psk: string): void {
        if (!net || psk === "")
            return;
        root.wifiMessage = "";
        root.wifiAsk = "";
        root.pendingNet = net;
        net.connectWithPsk(psk);
    }

    function cancelWifiAsk(): void {
        root.wifiAsk = "";
        root.wifiMessage = "";
        root.pendingNet = null;
    }

    Connections {
        target: root.pendingNet
        ignoreUnknownSignals: true

        function onConnectionFailed(reason): void {
            const net = root.pendingNet;
            root.pendingNet = null;
            if (!net)
                return;
            if (reason === ConnectionFailReason.NoSecrets && root.takesPsk(net)) {
                root.wifiAsk = net.name;
                return;
            }
            root.wifiAsk = "";
            switch (reason) {
            case ConnectionFailReason.NoSecrets:
                root.wifiMessage = "This network needs credentials the shell cannot supply";
                break;
            case ConnectionFailReason.WifiAuthTimeout:
                root.wifiMessage = "Authentication timed out";
                break;
            case ConnectionFailReason.WifiNetworkLost:
                root.wifiMessage = "The network went out of range";
                break;
            default:
                root.wifiMessage = "Could not connect";
                break;
            }
            wifiClear.restart();
        }

        function onConnectedChanged(): void {
            if (root.pendingNet?.connected) {
                root.pendingNet = null;
                root.wifiAsk = "";
                root.wifiMessage = "";
            }
        }
    }

    Timer {
        id: wifiClear
        interval: 9000
        onTriggered: root.wifiMessage = ""
    }

    // ── A network's saved profile ─────────────────────────────────────
    //
    // NetworkManager keeps one settings profile per known network, and
    // Quickshell hands it over whole: read() gives the nested
    // { group: { key: value } } map, write() takes a partial one back and
    // saves it to disk. Defaults are simply absent from the map, so
    // "autoconnect is not in there" means autoconnect is on, not off.
    function profileOf(net: var): var {
        const list = net?.nmSettings ?? [];
        return list.length > 0 ? list[0] : null;
    }

    function readProfile(net: var): var {
        return root.profileOf(net)?.read() ?? ({});
    }

    // Only what changed, which is all write() wants. A null value removes
    // the key and puts the default back.
    function writeProfile(net: var, patch: var): bool {
        const st = root.profileOf(net);
        if (!st)
            return false;
        st.write(patch);
        return true;
    }

    function group(map: var, name: string): var {
        return (map && map[name]) ? map[name] : ({});
    }

    // NM leaves a default out of the map entirely, so every read goes
    // through a fallback rather than trusting the key to be there.
    function autoconnectOf(map: var): bool {
        const v = root.group(map, "connection").autoconnect;
        return v === undefined ? true : v === true;
    }

    // 0 unknown, 1 metered, 2 not metered. Anything else is NM's guess.
    function meteredOf(map: var): int {
        const v = root.group(map, "connection").metered;
        return v === undefined ? 0 : v;
    }

    function hiddenOf(map: var): bool {
        return root.group(map, "802-11-wireless").hidden === true;
    }

    function ipv4MethodOf(map: var): string {
        return root.group(map, "ipv4").method ?? "auto";
    }

    // address-data is the readable form: [{ address, prefix }].
    function ipv4AddressOf(map: var): string {
        const list = root.group(map, "ipv4")["address-data"] ?? [];
        if (list.length === 0)
            return "";
        const a = list[0];
        return (a.address ?? "") + "/" + (a.prefix ?? 24);
    }

    function ipv4GatewayOf(map: var): string {
        return root.group(map, "ipv4").gateway ?? "";
    }

    function ipv4DnsOf(map: var): string {
        const d = root.group(map, "ipv4")["dns-data"] ?? [];
        return d.join(", ");
    }

    function clearSecrets(net: var): void {
        root.profileOf(net)?.clearSecrets();
    }

    function forgetNetwork(net: var): void {
        if (net)
            net.forget();
    }

    // ── Joining a network that is not on the list ─────────────────────
    //
    // Through nmcli, and deliberately: the backend can connect, forget
    // and rewrite a profile, but it has no call that creates one, so a
    // hidden SSID you type in has nothing to attach to. Passed as argv
    // rather than through a shell, so a passphrase with a quote in it
    // cannot become part of the command.
    property string addMessage: ""
    property bool addBusy: false

    function addNetwork(ssid: string, psk: string, hidden: bool): void {
        const name = (ssid ?? "").trim();
        if (name === "" || !root.wifiDevice)
            return;
        const argv = ["nmcli", "device", "wifi", "connect", name,
                      "ifname", root.wifiDevice.name];
        if ((psk ?? "") !== "")
            argv.push("password", psk);
        if (hidden)
            argv.push("hidden", "yes");
        root.addMessage = "";
        root.addBusy = true;
        adder.command = argv;
        adder.running = false;
        adder.running = true;
    }

    NProcess {
        id: adder
        // nmcli says why on stdout as well as stderr, and the reason is
        // the whole point of showing anything at all.
        quiet: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t !== "" && t.indexOf("successfully") < 0)
                    root.addMessage = t;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t !== "")
                    root.addMessage = t;
            }
        }
        onExited: (code) => {
            root.addBusy = false;
            if (code === 0 && root.addMessage === "")
                root.addMessage = "Connected";
            addClear.restart();
        }
    }

    Timer {
        id: addClear
        interval: 9000
        onTriggered: root.addMessage = ""
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

    NProcess {
        // Absent is an answer here, not a fault.
        quiet: true
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
