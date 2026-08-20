import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import ".."
import "../services"

// Battery tooltip, parked under the icon - not a CPU gauge.
NCard {
    id: root
    property bool shown: false
    property var batt: null
    readonly property bool hovered: ma.containsMouse

    implicitWidth: Theme.px(168)
    implicitHeight: col.implicitHeight + Theme.px(20)
    radius: Theme.r.chip
    visible: shown || opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    readonly property bool charging:
        batt?.state === UPowerDeviceState.Charging
    readonly property real pct: batt?.percentage ?? 0
    readonly property real watts: Math.abs(batt?.changeRate ?? 0)
    readonly property real eta: charging
        ? (batt?.timeToFull ?? 0)
        : (batt?.timeToEmpty ?? 0)
    readonly property bool hasEnergy:
        isFinite(batt?.energyCapacity ?? NaN) && (batt?.energyCapacity ?? 0) > 0

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(12)
        spacing: Theme.px(4)

        NLabel { text: "Battery"; dim: false }

        Text {
            text: Math.round(root.pct * 100) + "%"
            color: root.pct < 0.2 ? Theme.c.red : Theme.c.on
            font.family: Theme.f.display
            font.pixelSize: Theme.px(28)
            renderType: Text.QtRendering
        }

        Text {
            text: root.charging ? "Charging" : "On battery"
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.small
        }

        Text {
            visible: root.watts > 0.05
            text: root.watts.toFixed(1) + " W"
            color: Theme.c.onDim
            font.family: Theme.f.mono
            font.pixelSize: Theme.f.tiny
        }

        Text {
            visible: root.eta > 30 && root.eta < 86400
            text: (root.charging ? "Full in " : "Empty in ") + Time.duration(root.eta)
            color: Theme.c.onDim
            font.family: Theme.f.sans
            font.pixelSize: Theme.f.tiny
        }

        Text {
            visible: root.hasEnergy
            text: (root.batt.energy ?? 0).toFixed(1) + " / "
                + root.batt.energyCapacity.toFixed(1) + " Wh"
            color: Theme.c.onDim
            font.family: Theme.f.mono
            font.pixelSize: Theme.f.tiny
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
