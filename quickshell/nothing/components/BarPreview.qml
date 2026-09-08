import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// A miniature of the bar, drawn from the same three lists it configures.
//
// Glyphs rather than live elements: a real bar in a settings page means a
// second clock ticking, a second tray talking to DBus and a second
// battery poll, all to show an arrangement. The shapes are what is being
// arranged, and the shapes are enough.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: Theme.px(52)
    radius: Theme.r.chip
    color: Theme.veil(0.04)

    // The bar sits on a wallpaper, so the preview sits on a field of dots
    // rather than on the flat sheet: against nothing, the islands read as
    // rows in a list instead of as objects floating over a desktop.
    DotField {
        anchors.fill: parent
        step: Theme.px(9)
        dotRadius: Theme.px(0.8)
        baseAlpha: 0.5
    }

    component Island: Rectangle {
        required property var ids
        visible: ids.length > 0
        implicitWidth: row.implicitWidth + Theme.px(14)
        implicitHeight: Theme.px(20)
        // Theme.r.panel is set against the real bar's 30px; this island is
        // 20, so the radius is scaled with it. A preview that rounds
        // harder than the thing it previews is a lie about the shape.
        radius: Theme.px(3)
        color: Theme.c.surface
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(6)

            Repeater {
                model: parent.parent.ids
                NIcon {
                    required property string modelData
                    text: BarRegistry.icon(modelData)
                    size: Theme.px(9)
                    color: Theme.c.onDim
                }
            }
        }
    }

    Island {
        ids: Config.barLeft ? Config.barZone("left") : []
        anchors.left: parent.left
        anchors.leftMargin: Theme.px(8)
    }

    // The centre is one island per element in the real bar, but at this
    // size three pills with one glyph each are three specks: shown as one
    // group, which is what the arrangement actually says.
    Island {
        ids: Config.barCentre ? Config.barZone("centre") : []
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Island {
        ids: Config.barRight ? Config.barZone("right") : []
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(8)
    }
}
