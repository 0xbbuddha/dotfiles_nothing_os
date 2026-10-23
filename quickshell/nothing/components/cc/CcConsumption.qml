import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"

// Consumption and hardware, both: the two questions "what is this
// machine doing right now" and "what is this machine" sit close enough
// together that splitting them into two tabs would have meant flipping
// between them constantly.
ColumnLayout {
    id: root
    spacing: Theme.gap

    // One card shape, reused rather than redeclared six times: a
    // titled surface holding whatever rows a section needs.
    component Block: ColumnLayout {
        id: block
        property string title: ""
        default property alias content: inner.data

        Layout.fillWidth: true
        spacing: Theme.px(6)

        NLabel { text: block.title }

        NCard {
            Layout.fillWidth: true
            color: Theme.c.surface2
            radius: Theme.r.chip
            implicitHeight: inner.implicitHeight + Theme.px(18)

            ColumnLayout {
                id: inner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.px(9)
                spacing: Theme.px(6)
            }
        }
    }

    Block {
        title: "Processor"

        Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; history: Sys.cpuHistory; temp: Sys.cpuTemp }

        // Per core, at a glance: the shape worth seeing here is "is one
        // core pegged while the average looks fine", not each core's
        // own trend, so a snapshot row rather than eight more Stats.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(2)
            spacing: Theme.px(3)
            visible: Sys.cpuCores.length > 0

            Repeater {
                model: Sys.cpuCores

                Rectangle {
                    id: core
                    required property real modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(22)
                    radius: Theme.px(2)
                    color: Theme.c.surface3

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * Math.max(0.08, core.modelData)
                        radius: Theme.px(2)
                        color: core.modelData > 0.85 ? Theme.c.red : Theme.c.on
                        Behavior on height { NumberAnimation { duration: Theme.fast } }
                    }
                }
            }
        }

        NText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(2)
            text: Sys.cpuModel
            visible: Sys.cpuModel !== ""
            color: Theme.c.onDim
            elide: Text.ElideRight
        }
    }

    Block {
        title: "Memory"

        Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram; history: Sys.ramHistory }
        NText { Layout.fillWidth: true; text: Sys.ramDetail; color: Theme.c.onDim }

        Stat {
            label: "Zram"; icon: "󰍛"
            value: Sys.zram; history: Sys.zramHistory
            visible: Sys.hasZram
        }
        NText {
            Layout.fillWidth: true; text: Sys.zramDetail
            color: Theme.c.onDim; visible: Sys.hasZram
        }

        Stat {
            label: "Swap"; icon: "󰓡"
            value: Sys.diskSwap; history: Sys.swapHistory
            visible: Sys.hasDiskSwap
        }
        NText {
            Layout.fillWidth: true; text: Sys.swapDetail
            color: Theme.c.onDim; visible: Sys.hasDiskSwap
        }
    }

    Block {
        title: "Graphics"
        visible: Sys.gpuSeen

        Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; history: Sys.gpuHistory; temp: Sys.gpuTemp; hotAt: 85 }
        NText {
            Layout.fillWidth: true
            text: Sys.gpuModel
            visible: Sys.gpuModel !== ""
            color: Theme.c.onDim
            elide: Text.ElideRight
        }
    }

    Block {
        title: "Storage"

        Stat { label: "Disk"; icon: "󰋊"; value: Sys.disk }
        NText { Layout.fillWidth: true; text: Sys.diskDetail; color: Theme.c.onDim }
    }

    Block {
        title: "Battery"
        visible: Batt.present

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)

            NIcon { text: Batt.charging ? "󰂄" : "󰁹"; size: Theme.z.icon; color: Theme.c.onDim }
            NText {
                Layout.fillWidth: true
                text: Batt.charging ? "Charging" : (Batt.full ? "Full" : "On battery")
            }
            NText { text: Batt.percent + "%"; font.family: Theme.f.mono; color: Theme.c.on }
        }
        NText {
            Layout.fillWidth: true
            visible: Batt.knowsTime
            text: (Batt.charging ? "Full in " : "") + Batt.pretty(Batt.secondsLeft)
            color: Theme.c.onDim
        }
        NText {
            Layout.fillWidth: true
            visible: Batt.knowsHealth
            text: "Health  " + Batt.health + "%"
            color: Theme.c.onDim
        }
    }

    Block {
        title: "Machine"

        NText { Layout.fillWidth: true; text: Sys.distro; visible: Sys.distro !== "" }
        NText {
            Layout.fillWidth: true
            text: "Kernel  " + Sys.kernel
            color: Theme.c.onDim
            visible: Sys.kernel !== ""
        }
        NText { Layout.fillWidth: true; text: "Up  " + Sys.prettyUptime(); color: Theme.c.onDim }
    }
}
