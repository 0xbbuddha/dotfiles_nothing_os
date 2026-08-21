import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import ".."
import "../components"
import "../services"

// Small Wi-Fi or Bluetooth panel, independent of settings.
Item {
    id: root
    readonly property string kind: GlobalState.netPanel
    readonly property bool open: kind !== ""

    implicitWidth: Theme.px(320)
    implicitHeight: card.implicitHeight
    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? 0 : -Theme.px(8)

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    onOpenChanged: {
        Net.scanWifi(open && kind === "wifi");
        Net.scanBt(open && kind === "bt" && Net.btConnected.length === 0);
    }

    // Discovery is renewed only while nothing is connected or mid
    // handshake. An active scan steals the radio from A2DP, and blindly
    // restarting it every 25 seconds knocked a freshly connected speaker
    // straight back off. It also stands down the moment a device starts
    // connecting, which is why the guard is a binding and not just a
    // check inside onTriggered.
    readonly property bool mayScan: root.open && root.kind === "bt"
        && Net.btPowered && !Net.btWorking && Net.btConnected.length === 0

    onMayScanChanged: if (root.kind === "bt" && !mayScan) Net.scanBt(false)

    Timer {
        interval: 30000
        repeat: true
        running: root.mayScan
        onTriggered: if (!Net.btScanning) Net.scanBt(true)
    }

    NCard {
        id: card
        width: root.implicitWidth
        implicitHeight: col.implicitHeight + Theme.pad * 2

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.px(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NIcon {
                    text: root.kind === "bt" ? "󰂯" : Net.glyph
                    size: Theme.z.iconM
                    dy: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: root.kind === "bt" ? "Bluetooth" : "Wi-Fi"
                    color: Theme.c.on
                    font.family: Theme.f.sans
                    font.pixelSize: Theme.f.big
                    font.weight: Font.Medium
                }

                NSwitch {
                    checked: root.kind === "bt" ? Net.btPowered : Net.wifiEnabled
                    onToggled: (v) => {
                        if (root.kind === "bt") Net.toggleBt();
                        else Net.toggleWifi();
                    }
                }
            }

            // Says what the panel is doing. The scan already ran on open,
            // but nothing showed it, so the list read as frozen and the
            // only recourse was closing and reopening.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NLabel {
                    Layout.fillWidth: true
                    text: {
                        if (root.kind !== "bt")
                            return Net.name;
                        if (Net.btWorking)
                            return "CONNECTING";
                        if (Net.btScanning)
                            return "SCANNING";
                        return Net.btLabel;
                    }
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: Theme.px(5)
                    height: width
                    radius: width / 2
                    color: Theme.c.red
                    visible: root.kind === "bt" && (Net.btScanning || Net.btWorking)

                    SequentialAnimation on opacity {
                        running: parent.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 640 }
                        NumberAnimation { to: 1; duration: 640 }
                    }
                }

                CircleButton {
                    icon: "󰑐"
                    size: Theme.px(20)
                    visible: root.kind === "bt" && Net.btPowered
                    enabled: !Net.btScanning && !Net.btWorking
                    opacity: enabled ? 1 : 0.3
                    onActivated: Net.scanBt(true)
                }
            }

            // Says why nothing happened, which the panel never did.
            Text {
                Layout.fillWidth: true
                visible: root.kind === "bt" && Net.btMessage !== ""
                text: Net.btMessage
                color: Theme.c.red
                font.family: Theme.f.sans
                font.pixelSize: Theme.f.small
                wrapMode: Text.WordWrap
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Theme.px(240), listCol.implicitHeight)
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: root.kind === "wifi" ? Net.wifiEnabled : Net.btPowered

                ColumnLayout {
                    id: listCol
                    width: parent.width
                    spacing: Theme.px(4)

                    Repeater {
                        model: root.kind === "wifi"
                            ? (Net.wifiEnabled ? Net.sortedNetworks() : [])
                            : (Net.btPowered ? Net.sortedBt() : [])

                        Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool busy: root.kind === "bt"
                                && (modelData.pairing
                                    || modelData.state === BluetoothDeviceState.Connecting
                                    || modelData.state === BluetoothDeviceState.Disconnecting)
                            Layout.fillWidth: true
                            implicitHeight: Theme.px(36)
                            radius: Theme.r.tiny
                            color: modelData.connected ? Theme.c.surface3
                                 : (rma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(10)
                                anchors.rightMargin: Theme.px(10)
                                spacing: Theme.px(8)

                                NIcon {
                                    size: Theme.z.iconM
                                    dy: root.kind === "wifi" ? 1 : 0
                                    color: row.modelData.connected ? Theme.c.red : Theme.c.onDim
                                    text: {
                                        if (root.kind === "bt")
                                            return Net.btGlyph(row.modelData);
                                        const s = row.modelData.signalStrength ?? 0;
                                        if (s >= 75) return "󰤨";
                                        if (s >= 50) return "󰤥";
                                        if (s >= 25) return "󰤢";
                                        return "󰤟";
                                    }

                                    // Breathes while the device is mid-handshake,
                                    // so a click is visibly doing something.
                                    SequentialAnimation on opacity {
                                        running: root.kind === "bt" && row.busy
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 520 }
                                        NumberAnimation { to: 1; duration: 520 }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.kind === "bt"
                                        ? (row.modelData.name || row.modelData.address)
                                        : row.modelData.name
                                    color: Theme.c.on
                                    font.family: Theme.f.sans
                                    font.pixelSize: Theme.f.body
                                    elide: Text.ElideRight
                                }

                                NLabel {
                                    visible: root.kind === "bt"
                                          && (row.modelData.batteryAvailable ?? false)
                                    text: Math.round((row.modelData.battery ?? 0) * 100) + "%"
                                }

                                NLabel {
                                    text: {
                                        if (root.kind === "bt")
                                            return Net.btStatus(row.modelData);
                                        if (row.modelData.connected) return "connected";
                                        if (row.modelData.known) return "saved";
                                        return "";
                                    }
                                    color: row.modelData.connected ? Theme.c.red
                                         : (row.busy ? Theme.c.red : Theme.c.onDim)
                                }

                                // Drop a device the adapter still lists but
                                // that is no longer paired, or one you want
                                // to pair afresh.
                                CircleButton {
                                    icon: "󰅖"
                                    size: Theme.px(20)
                                    visible: root.kind === "bt" && rma.containsMouse
                                        && (row.modelData.paired || row.modelData.trusted)
                                    onActivated: row.modelData.forget()
                                }
                            }

                            MouseArea {
                                id: rma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = row.modelData;
                                    if (root.kind === "bt") {
                                        Net.btConnect(d);
                                    } else {
                                        if (d.connected) d.disconnect();
                                        else d.connect();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The way out when the built-in agent is not enough: a device
            // that wants a passkey typed needs a real manager.
            NPillButton {
                Layout.alignment: Qt.AlignLeft
                visible: root.kind === "bt" && Net.btPowered && Net.btWizard
                text: "PAIR A NEW DEVICE"
                onActivated: {
                    Net.openBtWizard();
                    GlobalState.netPanel = "";
                }
            }

            Text {
                Layout.fillWidth: true
                visible: (root.kind === "wifi" && Net.wifiEnabled && Net.networks.length === 0)
                      || (root.kind === "bt" && Net.btPowered && Net.btDevices.length === 0)
                text: "Looking…"
                color: Theme.c.onDim
                font.family: Theme.f.sans
                font.pixelSize: Theme.f.small
            }

            NLabel {
                visible: root.kind === "wifi" && !Net.wifiEnabled
                text: "Wi-Fi is off"
            }
            NLabel {
                visible: root.kind === "bt" && !Net.btPowered
                text: "Bluetooth is off"
            }
        }
    }
}
