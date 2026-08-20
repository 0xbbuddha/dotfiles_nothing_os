pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

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
