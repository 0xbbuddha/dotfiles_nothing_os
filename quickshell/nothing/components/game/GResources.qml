import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

ColumnLayout {
    anchors.fill: parent
    spacing: Theme.px(7)

    Stat { label: "CPU"; icon: "󰻠"; value: Sys.cpu; temp: Sys.cpuTemp }
    Stat { label: "RAM"; icon: "󰍛"; value: Sys.ram }
    Stat { label: "GPU"; icon: "󰢮"; value: Sys.gpu; temp: Sys.gpuTemp; visible: Sys.gpuSeen }
    Item { Layout.fillHeight: true }
}
