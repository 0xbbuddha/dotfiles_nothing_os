import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Machine load: CPU, RAM, GPU as dot gauges.
NCard {
    implicitHeight: col.implicitHeight + Theme.px(24)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.px(12)
        spacing: Theme.px(8)

        NLabel { text: "System" }

        Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; temp: Sys.cpuTemp }
        Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram }
        RecapDetail { text: Sys.ramDetail }
        Stat {
            label: "Zram"
            icon: "󰍛"
            value: Sys.zram
            visible: Sys.hasZram
        }
        RecapDetail { text: Sys.zramDetail; visible: Sys.hasZram }
        Stat {
            label: "Swap"
            icon: "󰓡"
            value: Sys.diskSwap
            visible: Sys.hasDiskSwap
        }
        RecapDetail { text: Sys.swapDetail; visible: Sys.hasDiskSwap }
        Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; temp: Sys.gpuTemp; visible: Sys.gpuSeen }
    }
}
