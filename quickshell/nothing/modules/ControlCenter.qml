import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../components/panels"
import "../components/widgets"
import "../services"

// The drop-down panel under the bar.
Item {
    id: root
    property bool open: false
    property bool calOpen: false

    // Which tile is expanded in place. Opening one from here used to fire
    // a separate flyout, which closed the control centre and threw the
    // panel to the other side of the screen: you lost your place to reach
    // a control you were already looking at.
    property string expanded: ""

    function expand(k: string): void {
        root.expanded = (root.expanded === k) ? "" : k;
    }

    property real maxHeight: Theme.px(720)
    signal requestClose()

    implicitWidth: Theme.z.panel
    implicitHeight: card.height

    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? 0 : -Theme.px(10)

    onOpenChanged: {
        if (!open) {
            calOpen = false;
            root.expanded = "";
        } else {
            Warp.refresh();
        }
    }
    onCalOpenChanged: if (calOpen) cal.goToday()

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    readonly property real naturalHeight:
        Theme.pad * 2 + header.implicitHeight + bodyCol.implicitHeight
        + footer.implicitHeight + Theme.gap * 2

    NCard {
        id: card
        width: root.implicitWidth
        height: Math.min(root.naturalHeight, root.maxHeight)
        radius: Theme.px(4)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.gap

            // ── Header: matrix clock + date ───────────────────────────
            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: Theme.px(8)

                DisplayText {
                    Layout.alignment: Qt.AlignBottom
                    text: Time.hhmm
                    size: Theme.px(34)
                }

                Text {
                    Layout.alignment: Qt.AlignBottom
                    text: Time.seconds
                    font.family: Theme.f.mono
                    font.pixelSize: Theme.f.body
                    color: Theme.c.onDim
                }

                Item { Layout.fillWidth: true }

                Item {
                    Layout.alignment: Qt.AlignBottom
                    implicitWidth: calCol.implicitWidth
                    implicitHeight: calCol.implicitHeight

                    ColumnLayout {
                        id: calCol
                        spacing: 0

                        NText {
                            Layout.alignment: Qt.AlignRight
                            text: Time.dateLong
                        }
                        NLabel {
                            Layout.alignment: Qt.AlignRight
                            text: root.calOpen ? "Close" : "Calendar"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calOpen = !root.calOpen
                    }
                }
            }

            Flickable {
                id: bodyFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: bodyCol.implicitHeight
                clip: true
                contentWidth: width
                contentHeight: bodyCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1

                ColumnLayout {
                    id: bodyCol
                    width: bodyFlick.width
                    spacing: Theme.gap

                    WCalendar {
                        id: cal
                        Layout.fillWidth: true
                        visible: root.calOpen
                    }

                    // ── Connectivity ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap

                        Toggle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Net.glyph
                            title: Net.kind === "ethernet" ? "Ethernet" : "Wi-Fi"
                            subtitle: Net.name
                            active: Net.kind !== "none"
                            onToggled: if (Net.kind !== "ethernet") Net.toggleWifi()
                            onSecondary: root.expand("wifi")
                        }

                        Toggle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Net.btConnected.length > 0 ? "󰂱" : "󰂯"
                            title: "Bluetooth"
                            subtitle: Net.btLabel
                            active: Net.btPowered
                            onToggled: Net.toggleBt()
                            onSecondary: root.expand("bt")
                        }

                        Toggle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            visible: Warp.available
                            icon: "󰖂"
                            title: "WARP"
                            subtitle: Warp.busy ? "…" : (Warp.connected ? "on" : "off")
                            active: Warp.connected
                            onToggled: Warp.toggle()
                        }
                    }

                    // Wi-Fi and Bluetooth open here, under their own tile,
                    // so the control you came from stays where you left it.
                    Item {
                        Layout.fillWidth: true
                        clip: true
                        readonly property bool on:
                            root.expanded === "wifi" || root.expanded === "bt"
                        implicitHeight: on ? netPanel.implicitHeight + Theme.px(10) : 0
                        opacity: on ? 1 : 0

                        Behavior on implicitHeight {
                            NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                        NetPanel {
                            id: netPanel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: Theme.px(10)
                            kind: root.expanded === "bt" ? "bt" : "wifi"
                            // Never scan for an expander nobody is looking
                            // at: it would hold the Bluetooth radio while
                            // the control centre is shut.
                            active: parent.on && root.open
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap

                        Toggle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Audio.muted ? "󰝟" : (Audio.volume > 0.5 ? "󰕾" : "󰖀")
                            title: "Sound"
                            subtitle: Audio.muted ? "muted" : (Math.round(Audio.volume * 100) + "%")
                            active: !Audio.muted
                            onToggled: if (Audio.audio) Audio.audio.muted = !Audio.audio.muted
                            onSecondary: root.expand("audio")
                        }

                        Toggle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            visible: Brightness.available
                            icon: Brightness.extraDim
                                ? "󰖔"
                                : (Brightness.value > 0.5 ? "󰃠" : "󰃞")
                            title: "Light"
                            subtitle: Math.round(Brightness.combined * 100) + "%"
                            active: true
                            onToggled: root.expand("light")
                            onSecondary: root.expand("light")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        readonly property bool on:
                            root.expanded === "audio" || root.expanded === "light"
                        implicitHeight: on ? avLoader.implicitHeight + Theme.px(10) : 0
                        opacity: on ? 1 : 0

                        Behavior on implicitHeight {
                            NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                        // Loaded on demand: unlike the network one, these
                        // two are different components, so a Loader is what
                        // picks between them anyway.
                        Loader {
                            id: avLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: Theme.px(10)
                            active: parent.on
                            sourceComponent: root.expanded === "light"
                                ? lightPanelC : audioPanelC
                        }
                    }

                    Component { id: audioPanelC; AudioPanel {} }
                    Component { id: lightPanelC; BrightnessPanel {} }

                    MediaCard { Layout.fillWidth: true }

                    Item {
                        Layout.fillWidth: true
                        visible: Updates.available && Updates.count > 0
                        implicitHeight: updRow.implicitHeight

                        RowLayout {
                            id: updRow
                            width: parent.width
                            spacing: Theme.px(8)

                            NIcon {
                                text: "󰚰"
                                size: Theme.z.iconM
                                color: Updates.urgent ? Theme.c.red : Theme.c.on
                            }
                            NText {
                                Layout.fillWidth: true
                                text: Updates.count + " update" + (Updates.count === 1 ? "" : "s")
                            }
                            NLabel { text: "install" }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Updates.install()
                        }
                    }

                    // Detailed used/free/zram stay on the bar hover:
                    // keep compact gauges here so they don't shove the footer.
                    NCard {
                        Layout.fillWidth: true
                        color: Theme.c.surface2
                        radius: Theme.r.chip
                        implicitHeight: sys.implicitHeight + Theme.px(18)

                        ColumnLayout {
                            id: sys
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.px(9)
                            spacing: Theme.px(7)

                            Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; history: Sys.cpuHistory; temp: Sys.cpuTemp }
                            Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram; history: Sys.ramHistory }
                            Stat {
                                label: "Zram"
                                icon: "󰍛"
                                value: Sys.zram; history: Sys.zramHistory
                                visible: Sys.hasZram
                            }
                            Stat {
                                label: "Swap"
                                icon: "󰓡"
                                value: Sys.diskSwap; history: Sys.swapHistory
                                visible: Sys.hasDiskSwap
                            }
                            Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; history: Sys.gpuHistory; temp: Sys.gpuTemp; visible: Sys.gpuSeen }
                        }
                    }
                }
            }

            // ── Footer: always visible ────────────────────────────────
            RowLayout {
                id: footer
                Layout.fillWidth: true
                spacing: Theme.gap

                NCard {
                    Layout.fillWidth: true
                    implicitHeight: Theme.px(30)
                    color: Theme.c.surface2
                    radius: Theme.r.chip

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(9)
                        spacing: Theme.px(7)

                        NIcon { text: "󰅶"; size: Theme.z.icon; color: Theme.c.onDim }
                        NLabel { text: "Caffeine"; dim: false; Layout.fillWidth: true }

                        NSwitch {
                            checked: Idle.inhibited
                            onToggled: (v) => Idle.apply(v)
                        }
                    }
                }

                SquareButton {
                    icon: "󰖔"
                    visible: NightLight.available
                    lit: NightLight.active
                    onActivated: NightLight.toggle()
                }
                SquareButton {
                    icon: "󰒓"
                    onActivated: { root.requestClose(); GlobalState.settingsOpen = true; }
                }
                SquareButton {
                    icon: "󰑐"
                    onActivated: { root.requestClose(); Power.reloadAll(); }
                }
                SquareButton {
                    icon: "󰌾"
                    onActivated: { root.requestClose(); Power.lock(); }
                }
                SquareButton {
                    icon: "󰐥"
                    danger: true
                    onActivated: { root.requestClose(); GlobalState.sessionOpen = true; }
                }
            }
        }
    }
}
