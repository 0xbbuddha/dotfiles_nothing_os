import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../.."
import ".."
import "../../services"

// Wi-Fi or Bluetooth, depending on `kind`. Hosted by the flyout and,
// inline, by the control centre.
//
// `active` is what drives scanning, so it has to be told whether the
// panel is really on screen: an inline copy inside a closed control
// centre must not hold the Bluetooth radio.
ColumnLayout {
    id: root

    property string kind: "wifi"
    property bool active: false

    onActiveChanged: {
        Net.scanWifi(root.active && root.kind === "wifi");
        Net.scanBt(root.active && root.kind === "bt" && Net.btConnected.length === 0);
    }

    // Discovery is renewed only while nothing is connected or mid
    // handshake. An active scan steals the radio from A2DP, and blindly
    // restarting it every 25 seconds knocked a freshly connected speaker
    // straight back off. It also stands down the moment a device starts
    // connecting, which is why the guard is a binding and not just a
    // check inside onTriggered.
    readonly property bool mayScan: root.active && root.kind === "bt"
        && Net.btPowered && !Net.btWorking && Net.btConnected.length === 0

    onMayScanChanged: if (root.kind === "bt" && !mayScan) Net.scanBt(false)

    Timer {
        interval: 30000
        repeat: true
        running: root.mayScan
        onTriggered: if (!Net.btScanning) Net.scanBt(true)
    }

    anchors.fill: parent
    spacing: Theme.px(8)

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(8)

        NIcon {
            text: root.kind === "bt" ? "󰂯" : Net.glyph
            size: Theme.z.iconM
            dy: 1
        }

        NText {
            Layout.fillWidth: true
            text: root.kind === "bt" ? "Bluetooth" : "Wi-Fi"
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
    NText {
        Layout.fillWidth: true
        visible: root.kind === "bt" && Net.btMessage !== ""
        text: Net.btMessage
        color: Theme.c.red
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
                    // Only ever one row asks at a time, and it is the one
                    // whose connection came back wanting a secret.
                    readonly property bool asking: root.kind === "wifi"
                        && Net.wifiAsk !== "" && Net.wifiAsk === modelData.name
                    readonly property bool busy: root.kind === "bt"
                        && (modelData.pairing
                            || modelData.state === BluetoothDeviceState.Connecting
                            || modelData.state === BluetoothDeviceState.Disconnecting)
                    Layout.fillWidth: true
                    implicitHeight: Theme.px(36)
                        + (row.asking ? Theme.px(42) : 0)
                    Behavior on implicitHeight {
                        NumberAnimation { duration: Theme.fast; easing.type: Theme.ease }
                    }
                    radius: Theme.r.tiny
                    clip: true
                    color: modelData.connected ? Theme.c.surface3
                         : (rma.containsMouse ? Theme.c.surface3 : Theme.c.surface2)

                    RowLayout {
                        id: line
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.px(36)
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

                        NText {
                            Layout.fillWidth: true
                            text: root.kind === "bt"
                                ? (row.modelData.name || row.modelData.address)
                                : row.modelData.name
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

                    // Asked for only when NetworkManager says it has no
                    // secret for this network, never up front: a network
                    // it already knows joins without a word.
                    RowLayout {
                        anchors.top: line.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        anchors.topMargin: Theme.px(2)
                        height: Theme.px(34)
                        visible: row.asking
                        spacing: Theme.px(6)

                        NField {
                            id: psk
                            Layout.fillWidth: true
                            implicitWidth: 0
                            implicitHeight: Theme.px(30)
                            secret: true
                            placeholder: "Password"
                            onCommitted: (v) => {
                                Net.connectWifiPsk(row.modelData, v);
                                psk.clear();
                            }
                            // The field appears because a click already
                            // happened, so it takes the keyboard rather
                            // than making you click again.
                            onVisibleChanged: if (visible) takeFocus()
                        }

                        CircleButton {
                            icon: "󰅖"
                            size: Theme.px(22)
                            onActivated: { psk.clear(); Net.cancelWifiAsk(); }
                        }
                    }

                    MouseArea {
                        id: rma
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.px(36)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = row.modelData;
                            if (root.kind === "bt")
                                Net.btConnect(d);
                            else
                                Net.connectWifi(d);
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

    NText {
        Layout.fillWidth: true
        visible: (root.kind === "wifi" && Net.wifiEnabled && Net.networks.length === 0)
              || (root.kind === "bt" && Net.btPowered && Net.btDevices.length === 0)
        text: "Looking…"
        color: Theme.c.onDim
    }

    // A refused connection used to leave the row exactly as it was,
    // which is indistinguishable from nothing having happened.
    NText {
        Layout.fillWidth: true
        visible: root.kind === "wifi" && Net.wifiMessage !== ""
        text: Net.wifiMessage
        color: Theme.c.red
        wrapMode: Text.WordWrap
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
