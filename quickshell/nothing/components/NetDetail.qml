import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// Everything NetworkManager keeps about one saved network.
//
// The profile is read whole and written back in pieces: write() takes a
// partial { group: { key: value } } map, and a null value removes a key
// and restores its default. Defaults are absent from the map NM hands
// back, so every reader here has a fallback rather than trusting the key
// to be present.
ColumnLayout {
    id: root
    required property var network

    property var map: ({})
    property bool raw: false

    readonly property bool known: root.network?.known ?? false

    function reload(): void {
        root.map = Net.readProfile(root.network);
    }

    function patch(group: string, key: string, value: var): void {
        const p = {};
        p[group] = {};
        p[group][key] = value;
        Net.writeProfile(root.network, p);
        // NM answers the write asynchronously; re-read a moment later so
        // the switches show what was actually stored rather than what we
        // asked for.
        settle.restart();
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.reload()
    }

    Component.onCompleted: root.reload()

    // The profile is not there at construction and does not have to be:
    // the delegate is built before the network is assigned, and NM only
    // hands over a profile once the network is known. Reading once on
    // completion left every field showing its default, which looks
    // exactly like a correctly loaded profile and hides the fault.
    onNetworkChanged: root.reload()

    Connections {
        target: root.network
        ignoreUnknownSignals: true
        function onNmSettingsChanged(): void { root.reload(); }
        function onKnownChanged(): void { root.reload(); }
    }

    Layout.fillWidth: true
    spacing: Theme.px(6)

    NText {
        Layout.fillWidth: true
        visible: !root.known
        text: "Nothing is saved for this network yet. Connect to it once "
            + "and its settings appear here."
        color: Theme.c.onDim
        wrapMode: Text.WordWrap
    }

    // ── The three that matter most ────────────────────────────────────
    SettingRow {
        visible: root.known
        label: "Connect automatically"
        hint: "Join this network whenever it is in range"
        DotSwitch {
            checked: Net.autoconnectOf(root.map)
            onToggled: (v) => root.patch("connection", "autoconnect", v)
        }
    }

    SettingRow {
        visible: root.known
        label: "Hidden network"
        hint: "The access point does not broadcast its name"
        DotSwitch {
            checked: Net.hiddenOf(root.map)
            onToggled: (v) => root.patch("802-11-wireless", "hidden", v)
        }
    }

    NLabel { visible: root.known; text: "Metered"; Layout.topMargin: Theme.px(4) }

    DotPicker {
        visible: root.known
        // NM's own numbering: 0 unknown, 1 metered, 2 not metered.
        options: [
            { label: "Automatic", value: 0 },
            { label: "Metered",   value: 1 },
            { label: "Unmetered", value: 2 }
        ]
        current: Net.meteredOf(root.map)
        onPicked: (v) => root.patch("connection", "metered", v)
    }

    // ── IPv4 ──────────────────────────────────────────────────────────
    NLabel { visible: root.known; text: "I P v 4"; Layout.topMargin: Theme.px(8) }

    DotPicker {
        visible: root.known
        options: [
            { label: "Automatic", value: "auto" },
            { label: "Manual",    value: "manual" },
            { label: "Off",       value: "disabled" }
        ]
        current: Net.ipv4MethodOf(root.map)
        onPicked: (v) => {
            if (v === "manual") {
                // Switching to manual on its own would leave NM with a
                // method it cannot satisfy, so the address goes with it.
                root.patch("ipv4", "method", "manual");
                return;
            }
            // Back to automatic: clear what manual left behind, or NM
            // keeps applying an address nobody asked for any more.
            Net.writeProfile(root.network, { ipv4: {
                method: v, "address-data": null, addresses: null,
                gateway: null, "dns-data": null, dns: null
            }});
            settle.restart();
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.known && Net.ipv4MethodOf(root.map) === "manual"
        spacing: Theme.px(6)

        SettingRow {
            label: "Address"
            hint: "With the prefix, for example 192.168.1.42/24"
            NField {
                implicitWidth: Theme.px(190)
                text: Net.ipv4AddressOf(root.map)
                placeholder: "192.168.1.42/24"
                onCommitted: (v) => {
                    const t = v.trim();
                    if (t === "") {
                        root.patch("ipv4", "address-data", null);
                        return;
                    }
                    const bits = t.split("/");
                    const prefix = parseInt(bits[1] ?? "24");
                    root.patch("ipv4", "address-data",
                        [{ address: bits[0], prefix: isNaN(prefix) ? 24 : prefix }]);
                }
            }
        }

        SettingRow {
            label: "Gateway"
            NField {
                implicitWidth: Theme.px(190)
                text: Net.ipv4GatewayOf(root.map)
                placeholder: "192.168.1.1"
                onCommitted: (v) => root.patch("ipv4", "gateway",
                                               v.trim() === "" ? null : v.trim())
            }
        }

        SettingRow {
            label: "DNS"
            hint: "Comma separated"
            NField {
                implicitWidth: Theme.px(190)
                text: Net.ipv4DnsOf(root.map)
                placeholder: "1.1.1.1, 9.9.9.9"
                onCommitted: (v) => {
                    const list = v.split(",").map(x => x.trim()).filter(x => x !== "");
                    root.patch("ipv4", "dns-data", list.length > 0 ? list : null);
                }
            }
        }
    }

    // ── The blunt instruments ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.px(8)
        visible: root.known
        spacing: Theme.px(8)

        NPillButton {
            text: "Clear password"
            onActivated: Net.clearSecrets(root.network)
        }

        NPillButton {
            text: "Forget"
            danger: true
            onActivated: Net.forgetNetwork(root.network)
        }

        Item { Layout.fillWidth: true }

        NPillButton {
            text: root.raw ? "Hide raw" : "Raw settings"
            onActivated: { root.raw = !root.raw; if (root.raw) root.reload(); }
        }
    }

    // ── The whole map, editable ───────────────────────────────────────
    NetRawEditor {
        Layout.fillWidth: true
        visible: root.known && root.raw
        network: root.network
        map: root.map
        onWrote: root.reload()
    }
}
