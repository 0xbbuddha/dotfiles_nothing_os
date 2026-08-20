import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// CPU / RAM / GPU recap on bar hover.
NCard {
    id: root
    property bool shown: false
    readonly property bool hovered: ma.containsMouse

    implicitWidth: Theme.px(320)
    implicitHeight: col.implicitHeight + Theme.px(20)
    radius: Theme.r.chip
    visible: shown || opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(10)
        spacing: Theme.px(7)

        NLabel { text: "System"; dim: false }

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

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
