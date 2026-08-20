import QtQuick
import QtQuick.Layouts
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
        Net.scanBt(open && kind === "bt");
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

            NLabel {
                text: root.kind === "bt" ? Net.btLabel : Net.name
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
                            : (Net.btPowered ? Net.btDevices : [])

                        Rectangle {
                            id: row
                            required property var modelData
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
                                            return row.modelData.connected ? "󰂱" : "󰂯";
                                        const s = row.modelData.signalStrength ?? 0;
                                        if (s >= 75) return "󰤨";
                                        if (s >= 50) return "󰤥";
                                        if (s >= 25) return "󰤢";
                                        return "󰤟";
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
                                        if (root.kind === "bt") {
                                            if (row.modelData.pairing) return "pairing";
                                            if (row.modelData.connected) return "connected";
                                            if (row.modelData.paired) return "paired";
                                            return "";
                                        }
                                        if (row.modelData.connected) return "connected";
                                        if (row.modelData.known) return "saved";
                                        return "";
                                    }
                                    color: row.modelData.connected ? Theme.c.red : Theme.c.onDim
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
                                        if (d.connected) d.disconnect();
                                        else if (d.paired) d.connect();
                                        else d.pair();
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
