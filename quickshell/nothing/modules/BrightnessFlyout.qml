import QtQuick
import QtQuick.Layouts
import ".."
import "../components"
import "../services"

// Light sliders, opened by clicking the Light pill.
// Screen: two phases (software gamma, then panel). Keyboard separate.
Item {
    id: root
    readonly property bool open: GlobalState.lightPanel

    implicitWidth: Theme.px(320)
    implicitHeight: card.implicitHeight
    visible: open || opacity > 0.01
    opacity: open ? 1 : 0
    y: open ? 0 : -Theme.px(8)

    Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.ease } }

    NCard {
        id: card
        width: root.implicitWidth
        implicitHeight: col.implicitHeight + Theme.pad * 2

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad
            spacing: Theme.px(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                NIcon {
                    text: Brightness.extraDim
                        ? "󰖔"
                        : (Brightness.value > 0.5 ? "󰃠" : "󰃞")
                    size: Theme.z.iconM
                }

                NText {
                    Layout.fillWidth: true
                    text: "Light"
                    font.pixelSize: Theme.f.big
                    font.weight: Font.Medium
                }
            }

            NLabel { text: "Screen" }

            LevelRow {
                Layout.fillWidth: true
                icon: Brightness.extraDim
                    ? "󰖔"
                    : (Brightness.value > 0.5 ? "󰃠" : "󰃞")
                value: Brightness.combined
                split: NightLight.available ? Brightness.split : -1
                accent: Brightness.extraDim ? Theme.c.onDim : Theme.c.on
                onMoved: (v) => Brightness.setCombined(v)
            }

            NLabel {
                text: "Keyboard"
                visible: Brightness.kbdAvailable
            }

            LevelRow {
                Layout.fillWidth: true
                visible: Brightness.kbdAvailable
                icon: Brightness.kbdValue > 0 ? "󰌌" : "󰌐"
                value: Brightness.kbdValue
                onMoved: (v) => Brightness.setKbd(v)
            }
        }
    }
}
