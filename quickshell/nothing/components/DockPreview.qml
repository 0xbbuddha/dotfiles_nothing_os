import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

// A miniature of the dock, drawn from the list it configures.
//
// Real icons, unlike the bar preview: an application's icon is the whole
// point of a dock, and a row of identical squares would say nothing about
// the order being edited.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: Theme.px(58)
    radius: Theme.r.chip
    color: Theme.veil(0.04)

    DotField {
        anchors.fill: parent
        step: Theme.px(9)
        dotRadius: Theme.px(0.8)
        baseAlpha: 0.5
    }

    readonly property var ids: Config.dockApps ? Config._list(Config.dockApps) ?? [] : []

    Rectangle {
        visible: root.ids.length > 0
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + Theme.px(16)
        implicitHeight: Theme.px(30)
        radius: Theme.r.pill
        color: Theme.c.surface

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.px(7)

            Repeater {
                model: root.ids

                AppIcon {
                    required property string modelData
                    appId: modelData
                    size: Theme.px(18)
                    width: size
                    height: size
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    NLabel {
        anchors.centerIn: parent
        visible: root.ids.length === 0
        text: "The dock is empty"
        color: Theme.c.onFaint
    }

    // Hidden entirely rather than shown greyed: a preview of something
    // switched off is a picture of a thing that is not there.
    opacity: Config.showDock ? 1 : 0.3
    Behavior on opacity { NumberAnimation { duration: Theme.med } }
}
