import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Machine load: CPU, RAM, GPU as dot gauges.
NCard {
    id: root
    // Reduced version: gauges only, no byte counts.
    property bool simple: false

    implicitHeight: col.implicitHeight + Theme.px(24)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.px(12)
        spacing: Theme.px(8)

        NLabel { text: "System" }

        Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; history: Sys.cpuHistory; temp: Sys.cpuTemp }
        Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram; history: Sys.ramHistory }
        RecapDetail { text: Sys.ramDetail; visible: !root.simple }
        Stat {
            label: "Zram"
            icon: "󰍛"
            value: Sys.zram; history: Sys.zramHistory
            visible: Sys.hasZram
        }
        RecapDetail { text: Sys.zramDetail; visible: Sys.hasZram && !root.simple }
        Stat {
            label: "Swap"
            icon: "󰓡"
            value: Sys.diskSwap; history: Sys.swapHistory
            visible: Sys.hasDiskSwap
        }
        RecapDetail { text: Sys.swapDetail; visible: Sys.hasDiskSwap && !root.simple }
        Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; history: Sys.gpuHistory; temp: Sys.gpuTemp; visible: Sys.gpuSeen }
    }
}
