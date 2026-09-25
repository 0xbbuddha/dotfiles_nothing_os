import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../components"
import "../components/panels"
import "../components/cc"
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

    // Which tab the body shows. "main" is the grid this panel has
    // always had; the rest are additions living beside it rather than
    // inside it, so nothing about the main tab had to move to make
    // room for them.
    property string ccTab: "main"
    readonly property var ccTabs: [
        // The one dot this house draws everywhere it means "the whole
        // thing at once" - the launcher's own mark, the disc on the
        // vinyl widget, a Glyph waking up.
        { label: "Main", value: "main", glyph: [
            "0011100",
            "0111110",
            "1111111",
            "1111111",
            "1111111",
            "0111110",
            "0011100"] },
        // Three bars climbing left to right - load over time, the same
        // idea the history bars next to every stat already draw.
        { label: "Usage", value: "sys", glyph: [
            "0000000",
            "0000010",
            "0000010",
            "0001010",
            "0001010",
            "0101010",
            "0101010"] },
        // Straight from Settings' own Network page, unchanged: the same
        // mark ought to mean the same thing wherever it turns up.
        { label: "Net", value: "net", glyph: [
            "1111111",
            "1000001",
            "0111110",
            "0100010",
            "0011100",
            "0000000",
            "0001000"] },
        // A ring opening outward - sound leaving a source, rather than
        // a literal speaker cone that a 7-dot grid cannot really draw.
        { label: "Sound", value: "audio", glyph: [
            "0011000",
            "0100100",
            "1000010",
            "1000010",
            "1000010",
            "0100100",
            "0011000"] },
        // The bind-rune the Bluetooth mark itself is built from,
        // simplified to fit the grid rather than redrawn from scratch.
        { label: "BT", value: "bt", glyph: [
            "0010000",
            "0011000",
            "0101100",
            "1001010",
            "0101100",
            "0011000",
            "0010000"] }
    ]

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
            root.ccTab = "main";
        } else {
            Warp.refresh();
        }
    }
    onCalOpenChanged: if (calOpen) cal.goToday()

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    readonly property real naturalHeight:
        Theme.pad * 2 + header.implicitHeight + tabBar.implicitHeight
        + (root.ccTab === "main" ? bodyCol.implicitHeight : extraCol.implicitHeight)
        + footer.implicitHeight + Theme.gap * 3

    NCard {
        id: card
        width: root.implicitWidth
        height: Math.min(root.naturalHeight, root.maxHeight)
        radius: Theme.r.panel
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
                            visible: Config.ccCalendar
                            text: root.calOpen ? "Close" : "Calendar"
                        }
                    }

                    // No calendar, no invitation to open one: the date
                    // stops offering the pointer as well as the label.
                    MouseArea {
                        anchors.fill: parent
                        enabled: Config.ccCalendar
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calOpen = !root.calOpen
                    }
                }
            }

            CcTabBar {
                id: tabBar
                Layout.fillWidth: true
                options: root.ccTabs
                current: root.ccTab
                onPicked: (v) => root.ccTab = v
            }

            Flickable {
                id: bodyFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: bodyCol.implicitHeight
                visible: root.ccTab === "main"
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
                        visible: root.calOpen && Config.ccCalendar
                    }

                    // ── The grid ──────────────────────────────────────
                    // One Flow, not two fixed rows. A tile whose service
                    // is missing hides itself, and a Flow closes up behind
                    // an invisible child instead of leaving the hole two
                    // hardcoded rows used to leave where WARP would go.
                    Flow {
                        id: grid
                        Layout.fillWidth: true
                        spacing: Theme.gap

                        readonly property int cols:
                            Math.max(2, Math.min(4, Config.ccColumns))
                        // Width is shared out here rather than by a layout:
                        // a Flow does not size its children, and tiles that
                        // each measured themselves would come out ragged.
                        readonly property real cellWidth:
                            (width - spacing * (cols - 1)) / cols

                        Repeater {
                            model: Config.ccTiles ? Config.ccZone("tiles") : []

                            CcTile {
                                id: tile
                                required property string modelData
                                required property int index
                                width: grid.cellWidth
                                height: Theme.px(42)
                                itemId: modelData
                                cc: root

                                // A grid that all lit up on the same frame
                                // read as one flat block; a cascade, tile
                                // by tile, reads as a panel switching on.
                                // Still no bounce - the delay is the only
                                // thing that varies, the curve underneath
                                // is the shell's usual one.
                                opacity: root.open ? 1 : 0
                                scale: root.open ? 1 : 0.92
                                Behavior on opacity {
                                    SequentialAnimation {
                                        PauseAnimation { duration: tile.index * 18 }
                                        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                                    }
                                }
                                Behavior on scale {
                                    SequentialAnimation {
                                        PauseAnimation { duration: tile.index * 18 }
                                        NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                                    }
                                }
                            }
                        }
                    }

                    // One expander under the whole grid, for all four of
                    // the tiles that open something in place. It used to be
                    // two, one under each row, which only worked while the
                    // rows were fixed and the right tiles were in them.
                    Item {
                        Layout.fillWidth: true
                        clip: true
                        readonly property bool on: root.expanded !== ""
                        implicitHeight: on ? expLoader.implicitHeight + Theme.px(10) : 0
                        opacity: on ? 1 : 0

                        Behavior on implicitHeight {
                            NumberAnimation { duration: Theme.med; easing.type: Theme.ease }
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                        Loader {
                            id: expLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: Theme.px(10)
                            active: parent.on
                            sourceComponent: {
                                switch (root.expanded) {
                                case "light": return lightPanelC;
                                case "audio": return audioPanelC;
                                default:      return netPanelC;
                                }
                            }
                        }
                    }

                    // Wi-Fi and Bluetooth share one panel that takes a
                    // kind, so it is built here rather than inline: the
                    // Loader above only picks between components.
                    Component {
                        id: netPanelC
                        NetPanel {
                            kind: root.expanded === "bt" ? "bt" : "wifi"
                            // Never scan for an expander nobody is looking
                            // at: it would hold the Bluetooth radio while
                            // the control centre is shut.
                            active: root.open
                                && (root.expanded === "wifi" || root.expanded === "bt")
                        }
                    }

                    Component { id: audioPanelC; AudioPanel {} }
                    Component { id: lightPanelC; BrightnessPanel {} }

                    MediaCard {
                        Layout.fillWidth: true
                        visible: Config.ccMedia
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: Config.ccUpdates
                            && Updates.available && Updates.count > 0
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
                        visible: Config.ccStats
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

            // ── The other tabs ───────────────────────────────────────
            // One Flickable, its content swapped by a Loader: the four
            // added tabs are not shown at once, so nothing is lost by
            // measuring and holding only whichever is current.
            Flickable {
                id: extraFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: extraCol.implicitHeight
                visible: root.ccTab !== "main"
                clip: true
                contentWidth: width
                contentHeight: extraCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height + 1

                Item {
                    id: extraCol
                    width: extraFlick.width
                    implicitHeight: extraLoader.item?.implicitHeight ?? 0

                    Loader {
                        id: extraLoader
                        width: parent.width
                        active: root.ccTab !== "main"
                        sourceComponent: {
                            switch (root.ccTab) {
                            case "sys":   return sysC;
                            case "net":   return netC;
                            case "audio": return audioC;
                            case "bt":    return btC;
                            default:      return null;
                            }
                        }
                    }
                }
            }

            Component { id: sysC; CcConsumption {} }
            Component { id: netC; NetPanel { kind: "wifi"; active: root.open && root.ccTab === "net" } }
            Component { id: audioC; AudioPanel {} }
            Component { id: btC; NetPanel { kind: "bt"; active: root.open && root.ccTab === "bt" } }

            // ── Footer ────────────────────────────────────────────────
            // Caffeine keeps its own full width row rather than joining
            // the grid: it is a switch with a label, not a state you read
            // at a glance, and squeezing it into a tile would have been a
            // redesign rather than a setting.
            RowLayout {
                id: footer
                Layout.fillWidth: true
                spacing: Theme.gap

                NCard {
                    Layout.fillWidth: true
                    visible: Config.ccCaffeine
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

                // With caffeine hidden the buttons would sit hard against
                // the left edge, which reads as a row that lost something.
                // This holds the space it used to take.
                Item {
                    Layout.fillWidth: true
                    visible: !Config.ccCaffeine
                }

                Repeater {
                    model: Config.ccFooter ? Config.ccZone("footer") : []

                    CcFooterSlot {
                        required property string modelData
                        itemId: modelData
                        cc: root
                    }
                }
            }
        }
    }
}
