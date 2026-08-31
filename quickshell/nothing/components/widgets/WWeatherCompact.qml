import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../services"

// Place and temperature on one line, with the icon. Everything else the
// full weather card shows is a glance too far for this size.
NCard {
    radius: Theme.r.chip

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        spacing: Theme.px(12)

        NIcon {
            text: Weather.glyph
            size: Theme.z.iconL
            color: Theme.c.on
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
                Layout.fillWidth: true
                text: Weather.desc
                elide: Text.ElideRight
            }
            NLabel { text: Weather.city }
        }

        NText {
            text: Weather.temp + "°"
            font.pixelSize: Theme.px(24)
            font.features: ({ "tnum": 1 })
        }
    }
}
