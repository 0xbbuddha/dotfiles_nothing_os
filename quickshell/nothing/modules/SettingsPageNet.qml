import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."
import "../components"
import "../services"

SettingsPage {
    id: page

    // The network whose settings are open, by name. One at a time: the
    // list is long enough without every row unfolded.
    property string opened: ""

    // The manual join form, folded away until asked for.
    property bool adding: false

    // Scan only while the page is shown.
    property bool active: visible && StackLayout.isCurrentItem
    onActiveChanged: { Net.scanWifi(active); Net.scanBt(active); }
    Component.onDestruction: { Net.scanWifi(false); Net.scanBt(false); }

    SettingsSection {
        title: "Wi-Fi"

        SettingRow {
            key: "wifi"
            label: "Enable Wi-Fi"
            hint: Net.wifiAvailable ? Net.name : "No Wi-Fi card detected"
            DotSwitch {
                checked: Net.wifiEnabled
                onToggled: Net.toggleWifi()
            }
        }

        Repeater {
            model: Net.wifiEnabled ? Net.sortedNetworks() : []

            ColumnLayout {
                id: netItem
                required property var modelData
                readonly property bool open: page.opened === netItem.modelData.name

                Layout.fillWidth: true
                spacing: Theme.px(4)

                Rectangle {
                    id: netRow
                    readonly property var modelData: netItem.modelData

                    Layout.fillWidth: true
                    implicitHeight: Theme.px(36)
                    radius: Theme.r.tiny
                    color: modelData.connected ? Theme.c.surface3
                         : (nma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        spacing: Theme.px(9)

                        NIcon {
                            size: Theme.z.iconM
                            color: netRow.modelData.connected ? Theme.c.red : Theme.c.onDim
                            text: {
                                const s = netRow.modelData.signalStrength ?? 0;
                                if (s >= 75) return "󰤨";
                                if (s >= 50) return "󰤥";
                                if (s >= 25) return "󰤢";
                                return "󰤟";
                            }
                        }

                        NText {
                            Layout.fillWidth: true
                            text: netRow.modelData.name
                            font.pixelSize: Theme.f.body
                            elide: Text.ElideRight
                        }

                        NIcon {
                            text: "󰌾"
                            size: Theme.z.icon
                            color: Theme.c.onFaint
                            visible: (netRow.modelData.security ?? WifiSecurityType.Open)
                                !== WifiSecurityType.Open
                        }

                        NLabel {
                            text: netRow.modelData.connected ? "connected"
                                : (netRow.modelData.known ? "saved" : "")
                            color: netRow.modelData.connected ? Theme.c.red : Theme.c.onDim
                        }

                        CircleButton {
                            icon: page.opened === netRow.modelData.name ? "󰅃" : "󰅀"
                            size: Theme.px(22)
                            onActivated: page.opened =
                                page.opened === netRow.modelData.name
                                    ? "" : netRow.modelData.name
                        }
                    }

                    MouseArea {
                        id: nma
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        // Stops short of the chevron, which has its own job.
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.px(34)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Net.connectWifi(netRow.modelData)
                    }
                }

                // Asked for only when NetworkManager answers that it
                // has no secret for this network.
                RowLayout {
                    Layout.fillWidth: true
                    visible: Net.wifiAsk !== ""
                        && Net.wifiAsk === netItem.modelData.name
                    spacing: Theme.px(6)

                    NField {
                        id: pagePsk
                        Layout.fillWidth: true
                        implicitWidth: 0
                        secret: true
                        placeholder: "Password"
                        onCommitted: (v) => {
                            Net.connectWifiPsk(netItem.modelData, v);
                            pagePsk.clear();
                        }
                        onVisibleChanged: if (visible) takeFocus()
                    }

                    CircleButton {
                        icon: "󰅖"
                        size: Theme.px(22)
                        onActivated: { pagePsk.clear(); Net.cancelWifiAsk(); }
                    }
                }

                NetDetail {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.px(10)
                    Layout.bottomMargin: Theme.px(6)
                    visible: netItem.open
                    network: netItem.modelData
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: Net.wifiEnabled && Net.networks.length === 0
            text: "Looking for networks…"
            color: Theme.c.onDim
        }

        NText {
            Layout.fillWidth: true
            visible: Net.wifiMessage !== ""
            text: Net.wifiMessage
            color: Theme.c.red
            wrapMode: Text.WordWrap
        }

        // ── A network the scan cannot show you ────────────────────────
        //
        // Through nmcli, because the backend can connect to a network,
        // rewrite its profile and forget it, but has no call that
        // creates one. A hidden SSID never appears in the scan, so there
        // is nothing to click and nothing to attach a profile to.
        SettingRow {
            key: "wifiAdd"
            label: "Add a network"
            hint: "For a hidden name the scan cannot see"
            interactive: true
            visible: Net.wifiEnabled
            onActivated: page.adding = !page.adding
            NIcon {
                text: page.adding ? "󰅃" : "󰅀"
                size: Theme.z.icon
                color: Theme.c.onDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Net.wifiEnabled && page.adding
            spacing: Theme.px(6)

            SettingRow {
                label: "Name"
                hint: "The SSID, exactly as it is spelled"
                NField {
                    id: addSsid
                    implicitWidth: Theme.px(190)
                    placeholder: "MyNetwork"
                }
            }

            SettingRow {
                label: "Password"
                hint: "Leave empty for an open network"
                NField {
                    id: addPsk
                    implicitWidth: Theme.px(190)
                    secret: true
                    placeholder: "Password"
                }
            }

            SettingRow {
                label: "Hidden"
                hint: "The access point does not broadcast its name"
                DotSwitch {
                    id: addHidden
                    checked: true
                    onToggled: (v) => checked = v
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NPillButton {
                    text: Net.addBusy ? "Joining…" : "Join"
                    opacity: Net.addBusy ? 0.5 : 1
                    onActivated: {
                        if (Net.addBusy)
                            return;
                        Net.addNetwork(addSsid.text, addPsk.text, addHidden.checked);
                        addPsk.clear();
                    }
                }

                NText {
                    Layout.fillWidth: true
                    text: Net.addMessage
                    color: Net.addMessage === "Connected" ? Theme.c.onDim : Theme.c.red
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    SettingsSection {
        title: "Bluetooth"

        SettingRow {
            key: "bluetooth"
            label: "Enable Bluetooth"
            hint: Net.adapter ? Net.btLabel : "No adapter"
            DotSwitch {
                checked: Net.btPowered
                onToggled: Net.toggleBt()
            }
        }

        Repeater {
            model: Net.btPowered ? Net.btDevices : []

            Rectangle {
                id: btRow
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Theme.px(36)
                radius: Theme.r.tiny
                color: modelData.connected ? Theme.c.surface3
                     : (bma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(9)

                    NIcon {
                        text: btRow.modelData.connected ? "󰂱" : "󰂯"
                        size: Theme.z.iconM
                        color: btRow.modelData.connected ? Theme.c.red : Theme.c.onDim
                    }

                    NText {
                        Layout.fillWidth: true
                        text: btRow.modelData.name || btRow.modelData.address
                        font.pixelSize: Theme.f.body
                        elide: Text.ElideRight
                    }

                    NLabel {
                        visible: btRow.modelData.batteryAvailable ?? false
                        text: Math.round((btRow.modelData.battery ?? 0) * 100) + "%"
                    }

                    NLabel {
                        text: btRow.modelData.pairing ? "appairage…"
                            : (btRow.modelData.connected ? "connected"
                            : (btRow.modelData.paired ? "paired" : ""))
                        color: btRow.modelData.connected ? Theme.c.red : Theme.c.onDim
                    }
                }

                MouseArea {
                    id: bma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = btRow.modelData;
                        if (d.connected) d.disconnect();
                        else if (d.paired) d.connect();
                        else d.pair();
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: Net.btPowered && Net.btDevices.length === 0
            text: "Looking for devices…"
            color: Theme.c.onDim
        }
    }
}
