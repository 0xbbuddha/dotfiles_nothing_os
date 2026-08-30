import QtQuick
import QtQuick.Layouts
import "../.."
import ".."
import "../../services"

// Light sliders: screen in two phases (software gamma, then panel),
// keyboard on its own. Hosted by the flyout and, inline, by the
// control centre.
ColumnLayout {
    id: root
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
