import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

SettingsPage {
    id: page

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

            Rectangle {
                id: netRow
                required property var modelData

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
                        visible: (netRow.modelData.security ?? 0) !== 0
                    }

                    NLabel {
                        text: netRow.modelData.connected ? "connected"
                            : (netRow.modelData.known ? "saved" : "")
                        color: netRow.modelData.connected ? Theme.c.red : Theme.c.onDim
                    }
                }

                MouseArea {
                    id: nma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (netRow.modelData.connected) netRow.modelData.disconnect();
                        else netRow.modelData.connect();
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            visible: Net.wifiEnabled && Net.networks.length === 0
            text: "Looking for networks…"
            color: Theme.c.onDim
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
