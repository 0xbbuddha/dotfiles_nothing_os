import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

ColumnLayout {
    anchors.fill: parent
    spacing: Theme.px(7)

    Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; history: Sys.cpuHistory; temp: Sys.cpuTemp }
    Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram; history: Sys.ramHistory }
    Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; history: Sys.gpuHistory; temp: Sys.gpuTemp; visible: Sys.gpuSeen }
    Item { Layout.fillHeight: true }
}
